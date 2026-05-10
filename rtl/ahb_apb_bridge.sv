// AHB-to-APB Bridge — iverilog compatible version
// Saras Chandra Kannam — personal portfolio
//
// Bridges an AHB master to up to 4 APB peripherals.
// FSM: IDLE -> SAMPLE -> SETUP -> ENABLE -> RESP -> IDLE
//
// APB slave address map (default):
//   Slave 0: 0x4000_xxxx
//   Slave 1: 0x4001_xxxx
//   Slave 2: 0x4002_xxxx
//   Slave 3: 0x4003_xxxx
//
// TODO: burst support (HBURST), HRESP ERROR on unmapped address
// FIXME: single-cycle SAMPLE state adds one extra wait cycle — could
//        optimize to go IDLE->SETUP directly for registered decoders

`timescale 1ns/1ps

module ahb_apb_bridge #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_SLAVES = 4,
    // flat packed slave base addresses — 4 x 32-bit, index 0 at MSB
    parameter [NUM_SLAVES*ADDR_WIDTH-1:0] SLAVE_BASES =
        {32'h4003_0000, 32'h4002_0000, 32'h4001_0000, 32'h4000_0000},
    parameter [ADDR_WIDTH-1:0] SLAVE_MASK = 32'hFFFF_0000
)(
    input  wire                  HCLK, HRESETn,
    input  wire                  HSEL,
    input  wire                  HREADY_IN,
    input  wire [1:0]            HTRANS,
    input  wire                  HWRITE,
    input  wire [ADDR_WIDTH-1:0] HADDR,
    input  wire [DATA_WIDTH-1:0] HWDATA,
    output reg  [DATA_WIDTH-1:0] HRDATA,
    output wire                  HREADY,
    output reg                   HRESP,

    output reg  [ADDR_WIDTH-1:0] PADDR,
    output reg                   PWRITE,
    output reg  [DATA_WIDTH-1:0] PWDATA,
    output reg  [NUM_SLAVES-1:0] PSEL,
    output reg                   PENABLE,
    input  wire [DATA_WIDTH-1:0] PRDATA,
    input  wire                  PREADY,
    input  wire                  PSLVERR
);

    localparam HTRANS_NONSEQ = 2'b10;

    // FSM states
    localparam [2:0]
        ST_IDLE    = 3'd0,
        ST_SAMPLE  = 3'd1,
        ST_SETUP   = 3'd2,
        ST_ENABLE  = 3'd3,
        ST_RESP    = 3'd4;

    reg [2:0] state, next_state;

    // saved AHB request
    reg [ADDR_WIDTH-1:0] saved_addr;
    reg [DATA_WIDTH-1:0] saved_wdata;
    reg                  saved_write;
    reg [NUM_SLAVES-1:0] saved_sel;

    // decode slave select from HADDR
    reg [NUM_SLAVES-1:0] slave_sel;
    integer k;
    always @(*) begin
        slave_sel = {NUM_SLAVES{1'b0}};
        for (k = 0; k < NUM_SLAVES; k = k + 1) begin
            if ((HADDR & SLAVE_MASK) ==
                (SLAVE_BASES[k*ADDR_WIDTH +: ADDR_WIDTH] & SLAVE_MASK))
                slave_sel[k] = 1'b1;
        end
    end

    // state register
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) state <= ST_IDLE;
        else          state <= next_state;
    end

    // next-state logic
    always @(*) begin
        next_state = state;
        case (state)
            ST_IDLE:    if (HSEL && HREADY_IN && HTRANS == HTRANS_NONSEQ)
                            next_state = ST_SAMPLE;
            ST_SAMPLE:  next_state = ST_SETUP;
            ST_SETUP:   next_state = ST_ENABLE;
            ST_ENABLE:  if (PREADY) next_state = ST_RESP;
            ST_RESP:    next_state = ST_IDLE;
            default:    next_state = ST_IDLE;
        endcase
    end

    // latch AHB request across two clock cycles:
    //   address phase (IDLE): capture HADDR/HWRITE/PSEL
    //   data phase (SAMPLE):  capture HWDATA (valid one cycle after address)
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            saved_addr  <= {ADDR_WIDTH{1'b0}};
            saved_wdata <= {DATA_WIDTH{1'b0}};
            saved_write <= 1'b0;
            saved_sel   <= {NUM_SLAVES{1'b0}};
        end else begin
            if (state == ST_IDLE && HSEL && HREADY_IN && HTRANS == HTRANS_NONSEQ) begin
                saved_addr  <= HADDR;
                saved_write <= HWRITE;
                saved_sel   <= slave_sel;
                // Note: DON'T capture HWDATA here — it's the previous cycle's data.
                // AHB write data is valid in the DATA phase (ST_SAMPLE).
            end
            if (state == ST_SAMPLE) begin
                saved_wdata <= HWDATA;  // now valid: data phase of AHB write
            end
        end
    end

    // APB outputs
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            PADDR   <= {ADDR_WIDTH{1'b0}};
            PWRITE  <= 1'b0;
            PWDATA  <= {DATA_WIDTH{1'b0}};
            PSEL    <= {NUM_SLAVES{1'b0}};
            PENABLE <= 1'b0;
            HRDATA  <= {DATA_WIDTH{1'b0}};
            HRESP   <= 1'b0;
        end else begin
            PSEL    <= {NUM_SLAVES{1'b0}};
            PENABLE <= 1'b0;
            HRESP   <= PSLVERR;
            case (state)
                ST_SAMPLE: begin
                    PADDR  <= saved_addr;
                    PWRITE <= saved_write;
                    // Note: don't assign PWDATA here — saved_wdata is latched
                    // at the same edge (NBA race). Use HWDATA directly in ST_SETUP.
                end
                ST_SETUP: begin
                    // HWDATA is still valid here: AHB master holds it stable
                    // until HREADY, which we deassert throughout the APB transfer.
                    PWDATA  <= HWDATA;
                    PSEL    <= saved_sel;
                    PENABLE <= 1'b0;
                end
                ST_ENABLE: begin
                    PSEL    <= saved_sel;
                    PENABLE <= 1'b1;
                    // Capture HRDATA while PSEL is still asserted (PRDATA valid).
                    // Can't do it in ST_RESP because PSEL is cleared by default above.
                    if (PREADY)
                        HRDATA <= PRDATA;
                end
                ST_RESP: ; // HRDATA already captured in ST_ENABLE
            endcase
        end
    end

    // HREADY low while APB transaction is in flight
    assign HREADY = (state == ST_IDLE || state == ST_RESP);

endmodule
