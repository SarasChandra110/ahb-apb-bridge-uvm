// AHB-to-APB Bridge
// Saras Chandra Kannam — personal portfolio
//
// Bridges a single AHB master to multiple APB peripherals.
// AHB is pipelined (address phase overlaps data phase of previous xfer).
// APB is simple 2-cycle: SETUP -> ENABLE, then back to IDLE.
//
// Supports:
//   - Single transfers only (no bursts — APB can't handle them)
//   - Up to 8 APB slaves via PSEL[7:0]
//   - PREADY extension (APB slave can add wait states)
//
// Known limitation: HRESP error response not fully implemented (always OKAY)
// TODO: add HBURST support and split/retry responses

module ahb_apb_bridge #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_SLAVES = 4,
    // base addresses for each APB slave — parameterized so testbench can override
    parameter logic [ADDR_WIDTH-1:0] SLAVE_BASE [NUM_SLAVES] = '{
        32'h4000_0000, 32'h4001_0000, 32'h4002_0000, 32'h4003_0000
    },
    parameter logic [ADDR_WIDTH-1:0] SLAVE_MASK = 32'hFFFF_0000
)(
    // AHB slave interface (connects to AHB master/interconnect)
    input  logic                  HCLK, HRESETn,
    input  logic                  HSEL,
    input  logic                  HREADY_IN,
    input  logic [1:0]            HTRANS,   // IDLE=0, BUSY=1, NONSEQ=2, SEQ=3
    input  logic                  HWRITE,
    input  logic [ADDR_WIDTH-1:0] HADDR,
    input  logic [DATA_WIDTH-1:0] HWDATA,
    output logic [DATA_WIDTH-1:0] HRDATA,
    output logic                  HREADY,
    output logic                  HRESP,    // 0=OKAY, 1=ERROR

    // APB master interface (connects to APB slaves)
    output logic [ADDR_WIDTH-1:0] PADDR,
    output logic                  PWRITE,
    output logic [DATA_WIDTH-1:0] PWDATA,
    output logic [NUM_SLAVES-1:0] PSEL,
    output logic                  PENABLE,
    input  logic [DATA_WIDTH-1:0] PRDATA,
    input  logic                  PREADY,
    input  logic                  PSLVERR
);

    // AHB transfer types
    localparam HTRANS_IDLE   = 2'b00;
    localparam HTRANS_NONSEQ = 2'b10;

    // Bridge FSM
    typedef enum logic [2:0] {
        ST_IDLE    = 3'b000,  // waiting for AHB transfer
        ST_SAMPLE  = 3'b001,  // sampled AHB address phase, holding HREADY low
        ST_SETUP   = 3'b010,  // APB SETUP phase (PSEL=1, PENABLE=0)
        ST_ENABLE  = 3'b011,  // APB ENABLE phase (PSEL=1, PENABLE=1)
        ST_RESP    = 3'b100   // driving HRDATA back to AHB master
    } state_t;

    state_t state, next_state;

    // registered AHB signals (sampled at end of address phase)
    logic [ADDR_WIDTH-1:0] saved_addr;
    logic [DATA_WIDTH-1:0] saved_wdata;
    logic                  saved_write;
    logic [NUM_SLAVES-1:0] saved_sel;

    // decode which APB slave is targeted
    logic [NUM_SLAVES-1:0] slave_sel;
    always_comb begin
        slave_sel = '0;
        for (int i = 0; i < NUM_SLAVES; i++) begin
            if ((HADDR & SLAVE_MASK) == (SLAVE_BASE[i] & SLAVE_MASK))
                slave_sel[i] = 1'b1;
        end
    end

    // state register
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) state <= ST_IDLE;
        else          state <= next_state;
    end

    // next-state logic
    always_comb begin
        next_state = state;
        case (state)
            ST_IDLE:   if (HSEL && HREADY_IN && HTRANS == HTRANS_NONSEQ)
                           next_state = ST_SAMPLE;
            ST_SAMPLE: next_state = ST_SETUP;
            ST_SETUP:  next_state = ST_ENABLE;
            ST_ENABLE: if (PREADY) next_state = ST_RESP;
            ST_RESP:   next_state = ST_IDLE;
        endcase
    end

    // sample AHB address phase
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            saved_addr  <= '0;
            saved_wdata <= '0;
            saved_write <= 1'b0;
            saved_sel   <= '0;
        end else if (state == ST_IDLE && HSEL && HREADY_IN &&
                     HTRANS == HTRANS_NONSEQ) begin
            saved_addr  <= HADDR;
            saved_wdata <= HWDATA;  // valid one cycle after address on AHB
            saved_write <= HWRITE;
            saved_sel   <= slave_sel;
        end
    end

    // APB outputs
    assign PADDR   = saved_addr;
    assign PWRITE  = saved_write;
    assign PWDATA  = saved_wdata;
    assign PSEL    = (state == ST_SETUP || state == ST_ENABLE) ? saved_sel : '0;
    assign PENABLE = (state == ST_ENABLE);

    // AHB outputs
    assign HRDATA = PRDATA;
    assign HRESP  = PSLVERR;  // map APB error to AHB error response
    // hold HREADY low while APB transaction is in progress
    assign HREADY = (state == ST_IDLE || state == ST_RESP);

endmodule
