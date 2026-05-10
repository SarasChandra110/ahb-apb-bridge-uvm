// Simulation top — iverilog compatible (no always_ff, no unpacked param arrays)
`timescale 1ns/1ps

module tb_top;
    reg         HCLK;
    reg         HRESETn;
    reg         HSEL;
    reg         HREADY_IN;
    reg  [1:0]  HTRANS;
    reg         HWRITE;
    reg  [31:0] HADDR;
    reg  [31:0] HWDATA;
    wire [31:0] HRDATA;
    wire        HREADY;
    wire        HRESP;
    wire [31:0] PADDR;
    wire        PWRITE;
    wire [31:0] PWDATA;
    wire [3:0]  PSEL;
    wire        PENABLE;
    reg  [31:0] PRDATA;
    reg         PREADY;
    reg         PSLVERR;

    // Per-slave memory — 4 slaves × 256 words
    // PSEL[i] determines which slave is active; PADDR[9:2] is the word index.
    reg [31:0] slave_mem [0:3][0:255];
    integer    s;

    always @(posedge HCLK) begin
        if (PENABLE && PWRITE) begin
            for (s = 0; s < 4; s = s + 1)
                if (PSEL[s]) slave_mem[s][PADDR[9:2]] <= PWDATA;
        end
    end

    always @(*) begin
        PRDATA = 32'h0;
        for (s = 0; s < 4; s = s + 1)
            if (PSEL[s]) PRDATA = slave_mem[s][PADDR[9:2]];
    end
    initial PREADY  = 1;
    initial PSLVERR = 0;

    ahb_apb_bridge dut (
        .HCLK(HCLK), .HRESETn(HRESETn),
        .HSEL(HSEL), .HREADY_IN(HREADY_IN),
        .HTRANS(HTRANS), .HWRITE(HWRITE),
        .HADDR(HADDR), .HWDATA(HWDATA),
        .HRDATA(HRDATA), .HREADY(HREADY), .HRESP(HRESP),
        .PADDR(PADDR), .PWRITE(PWRITE), .PWDATA(PWDATA),
        .PSEL(PSEL), .PENABLE(PENABLE),
        .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR)
    );

    initial HCLK = 0;
    always #5 HCLK = ~HCLK;

    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_top);
    end
endmodule
