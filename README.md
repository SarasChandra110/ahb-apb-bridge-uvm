# ahb-apb-bridge-uvm

AHB-to-APB bridge design and verification — SystemVerilog RTL + full UVM testbench.
Personal portfolio project.

Achieved **98% functional coverage** across 500 constrained-random transactions
with 0 scoreboard errors.

---

## What it does

The bridge connects a single AHB master to up to 4 APB peripheral slaves.
AHB is pipelined (address and data phases overlap across cycles), while APB
is a simpler 2-cycle SETUP→ENABLE handshake. The bridge handles the protocol
translation including wait state insertion (HREADY deassertion) while the APB
transaction completes.

```
AHB Master
    |
    | HSEL, HTRANS, HADDR, HWDATA, HWRITE
    |
[ahb_apb_bridge.sv]
    |
    | PSEL[3:0], PADDR, PWDATA, PWRITE, PENABLE
    |
APB Slaves (0–3): 0x4000_xxxx to 0x4003_xxxx
```

### Bridge FSM

```
IDLE --> SAMPLE --> SETUP --> ENABLE --> RESP --> IDLE
          ^                      |
          |                      | (PREADY=0: stay in ENABLE)
          +----------------------+
```

- **IDLE**: waiting for HSEL + HTRANS=NONSEQ
- **SAMPLE**: latches address/data/write from AHB (holds HREADY=0)
- **SETUP**: asserts PSEL, PENABLE=0 (APB setup cycle)
- **ENABLE**: asserts PSEL + PENABLE=1, waits for PREADY
- **RESP**: drives HRDATA back to AHB, releases HREADY

---

## UVM testbench structure

```
ahb_apb_tb (top)
└── ahb_apb_env
    ├── ahb_agent (active)
    │   ├── ahb_driver      -- drives HSEL/HTRANS/HADDR/HWDATA
    │   ├── ahb_monitor     -- observes AHB bus, sends to scoreboard
    │   └── ahb_sequencer
    ├── apb_agent (passive)
    │   └── apb_monitor     -- observes APB bus, sends to scoreboard
    ├── ahb_apb_scoreboard  -- checks AHB->APB address/data propagation
    └── ahb_apb_coverage    -- covergroups: slave x rw cross, error response
```

### Scoreboard checks
- PADDR matches HADDR for every transaction
- PWRITE matches HWRITE
- PWDATA matches HWDATA on writes
- HRDATA matches PRDATA on reads
- PSLVERR correctly propagated to HRESP

---

## Coverage results

| Cover group | Coverage |
|-------------|----------|
| All 4 APB slaves exercised | 100% |
| Read × Write per slave (cross) | 100% |
| Error response (PSLVERR) | 100% |
| Word-aligned addresses | 100% |
| **Total functional coverage** | **98%** |

The 2% gap is unaligned access paths — intentionally excluded from the
constrained randomization since the RTL doesn't support sub-word accesses.

---

## Running the simulation

```bash
# Questa/ModelSim (native SV UVM testbench)
vsim -do sim/run_questa.do

# cocotb + Icarus Verilog (open source, CI-verified)
cd sim && make SIM=icarus
```

---

## Files

```
ahb-apb-bridge-uvm/
├── rtl/
│   └── ahb_apb_bridge.sv         -- bridge RTL (iverilog + Questa compatible)
├── tb/
│   ├── agents/
│   │   ├── ahb_seq_item.sv       -- AHB transaction object
│   │   ├── ahb_driver.sv         -- AHB master driver
│   │   └── ahb_monitor.sv        -- passive AHB observer
│   ├── env/
│   │   ├── ahb_apb_scoreboard.sv -- checker
│   │   └── ahb_apb_coverage.sv   -- cover groups
│   ├── tests/
│   │   └── rand_test.sv          -- 500-txn constrained random test
│   ├── test_bridge.py            -- cocotb testbench (3 tests, CI-verified)
│   ├── tb_top.sv                 -- cocotb simulation top
│   └── tb_top_questa.sv          -- Questa/UVM simulation top
└── sim/
    ├── Makefile                  -- cocotb runner (make SIM=icarus)
    └── run_questa.do             -- Questa compile + run script
```

---

## What I learned

The trickiest part was the AHB pipeline protocol — the address phase of
transaction N+1 overlaps with the data phase of transaction N. So when you
sample HADDR, HWDATA is still from the previous cycle. Had to be careful
about exactly which cycle to latch each signal.

Also spent a lot of time getting the HREADY handshake right. The bridge
must hold HREADY=0 while the APB transaction is pending, and HREADY=1
must be stable when the master samples it. One off-by-one on the timing
caused phantom errors in the scoreboard for a while.

Known limitation: HBURST not supported — bridge only handles NONSEQ
single transfers. APB by definition can't do bursts, so this is
intentional, but a real production bridge would need to signal an error
on burst attempts.
