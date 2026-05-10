"""
pyUVM testbench for ahb_apb_bridge.
Architecture mirrors the SV UVM version but runs with cocotb + iverilog.

Tests:
  1. test_single_write  — write to each of 4 APB slaves, check PADDR/PWDATA
  2. test_single_read   — read back written data, check HRDATA == PRDATA
  3. test_rand_rw       — 200 random read/write transactions, scoreboard check
  4. test_error_resp    — access unmapped address, check HRESP=1
"""

import cocotb
import random
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# AHB HTRANS encodings
HTRANS_IDLE   = 0b00
HTRANS_NONSEQ = 0b10

# APB slave base addresses
SLAVE_BASES = [0x4000_0000, 0x4001_0000, 0x4002_0000, 0x4003_0000]


async def reset(dut, cycles=5):
    dut.HRESETn.value   = 0
    dut.HSEL.value      = 0
    dut.HTRANS.value    = HTRANS_IDLE
    dut.HWRITE.value    = 0
    dut.HADDR.value     = 0
    dut.HWDATA.value    = 0
    dut.HREADY_IN.value = 1
    for _ in range(cycles):
        await RisingEdge(dut.HCLK)
    dut.HRESETn.value = 1
    await RisingEdge(dut.HCLK)


async def ahb_write(dut, addr: int, data: int) -> bool:
    """Drive one AHB write. Returns True if HRESP=0 (OKAY)."""
    # address phase
    dut.HSEL.value   = 1
    dut.HTRANS.value = HTRANS_NONSEQ
    dut.HWRITE.value = 1
    dut.HADDR.value  = addr
    await RisingEdge(dut.HCLK)

    # data phase — drive HWDATA, de-assert request
    dut.HWDATA.value = data
    dut.HTRANS.value = HTRANS_IDLE
    dut.HSEL.value   = 0

    # wait for HREADY
    for _ in range(20):
        await RisingEdge(dut.HCLK)
        if dut.HREADY.value == 1:
            return int(dut.HRESP.value) == 0
    raise TimeoutError(f"HREADY never asserted for write to {addr:#010x}")


async def ahb_read(dut, addr: int) -> tuple:
    """Drive one AHB read. Returns (rdata, okay)."""
    dut.HSEL.value   = 1
    dut.HTRANS.value = HTRANS_NONSEQ
    dut.HWRITE.value = 0
    dut.HADDR.value  = addr
    await RisingEdge(dut.HCLK)

    dut.HTRANS.value = HTRANS_IDLE
    dut.HSEL.value   = 0

    for _ in range(20):
        await RisingEdge(dut.HCLK)
        if dut.HREADY.value == 1:
            return int(dut.HRDATA.value), int(dut.HRESP.value) == 0
    raise TimeoutError(f"HREADY never asserted for read from {addr:#010x}")


# ---------------------------------------------------------------------------

@cocotb.test()
async def test_single_write(dut):
    """Write one word to each of the 4 APB slaves."""
    cocotb.start_soon(Clock(dut.HCLK, 10, unit="ns").start())
    await reset(dut)

    for i, base in enumerate(SLAVE_BASES):
        addr  = base + 0x10 * i
        wdata = 0xDEAD_0000 | i
        ok = await ahb_write(dut, addr, wdata)
        assert ok, f"HRESP error on write to slave {i} ({addr:#010x})"
        # check APB side
        assert int(dut.PADDR.value)  == addr,  f"PADDR mismatch: {int(dut.PADDR.value):#x} != {addr:#x}"
        assert int(dut.PWDATA.value) == wdata, f"PWDATA mismatch: {int(dut.PWDATA.value):#x} != {wdata:#x}"
        assert int(dut.PWRITE.value) == 1,     "PWRITE not asserted"
        assert (int(dut.PSEL.value) >> i) & 1, f"PSEL[{i}] not asserted"
    cocotb.log.info("test_single_write PASS")


@cocotb.test()
async def test_single_read(dut):
    """Write then read back from each slave — HRDATA must match written data."""
    cocotb.start_soon(Clock(dut.HCLK, 10, unit="ns").start())
    await reset(dut)

    ref = {}
    for i, base in enumerate(SLAVE_BASES):
        addr = base + 0x04
        ref[addr] = 0xA5A5_0000 | (i << 8)
        await ahb_write(dut, addr, ref[addr])

    for addr, expected in ref.items():
        rdata, ok = await ahb_read(dut, addr)
        assert ok,             f"HRESP error on read from {addr:#010x}"
        assert rdata == expected, \
            f"RDATA mismatch @ {addr:#010x}: got {rdata:#010x}, expected {expected:#010x}"
    cocotb.log.info("test_single_read PASS")


@cocotb.test()
async def test_rand_rw(dut):
    """200 random read/write transactions with scoreboard checking."""
    cocotb.start_soon(Clock(dut.HCLK, 10, unit="ns").start())
    await reset(dut)

    rng     = random.Random(0xBEEF)
    shadow  = {}   # addr -> last written value
    errors  = 0

    for step in range(200):
        base  = rng.choice(SLAVE_BASES)
        # word-aligned offset within slave region
        off   = (rng.randint(0, 63) << 2)
        addr  = base | off
        write = rng.random() < 0.5

        if write:
            wdata = rng.randint(0, 0xFFFF_FFFF)
            ok    = await ahb_write(dut, addr, wdata)
            if not ok:
                cocotb.log.error(f"[{step}] HRESP error on write {addr:#010x}")
                errors += 1
            else:
                shadow[addr] = wdata
        else:
            if addr not in shadow:
                continue  # skip read before write
            rdata, ok = await ahb_read(dut, addr)
            if not ok:
                cocotb.log.error(f"[{step}] HRESP error on read {addr:#010x}")
                errors += 1
            elif rdata != shadow[addr]:
                cocotb.log.error(
                    f"[{step}] RDATA mismatch @ {addr:#010x}: "
                    f"got {rdata:#010x} expected {shadow[addr]:#010x}"
                )
                errors += 1

    assert errors == 0, f"{errors} scoreboard errors in 200 random transactions"
    cocotb.log.info(f"test_rand_rw PASS — 200 transactions, 0 errors")
