// Questa/UVM simulation top — uses the native SV UVM testbench
`timescale 1ns/1ps

module tb_top_questa;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    logic        HCLK, HRESETn;
    logic        HSEL, HREADY_IN;
    logic [1:0]  HTRANS;
    logic        HWRITE;
    logic [31:0] HADDR, HWDATA;
    wire  [31:0] HRDATA;
    wire         HREADY, HRESP;
    wire  [31:0] PADDR, PWDATA;
    wire         PWRITE;
    wire  [3:0]  PSEL;
    wire         PENABLE;
    reg   [31:0] PRDATA;
    reg          PREADY  = 1;
    reg          PSLVERR = 0;

    // Virtual interface for UVM
    // (ahb_apb_if needs to be defined for full UVM — simplified here)

    ahb_apb_bridge dut (.*);

    // APB slave model
    reg [31:0] slave_mem[0:3][0:255];
    integer s;
    always @(posedge HCLK) begin
        if (PENABLE && PWRITE)
            for (s = 0; s < 4; s++)
                if (PSEL[s]) slave_mem[s][PADDR[9:2]] <= PWDATA;
    end
    always @(*) begin
        PRDATA = 32'h0;
        for (s = 0; s < 4; s++)
            if (PSEL[s]) PRDATA = slave_mem[s][PADDR[9:2]];
    end

    initial HCLK = 0;
    always #5 HCLK = ~HCLK;

    initial begin
        HRESETn    = 0;
        HSEL       = 0;
        HREADY_IN  = 1;
        HTRANS     = 2'b00;
        HWRITE     = 0;
        HADDR      = 0;
        HWDATA     = 0;
        repeat(5) @(posedge HCLK);
        HRESETn = 1;
    end

    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_top_questa);
        run_test("rand_test");
    end
endmodule
