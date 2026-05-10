// AHB transaction — used by driver and scoreboard
// Saras Chandra Kannam

class ahb_seq_item extends uvm_sequence_item;
    `uvm_object_utils(ahb_seq_item)

    // transaction fields
    rand logic [31:0] addr;
    rand logic [31:0] data;
    rand logic        write;   // 1=write, 0=read
    rand logic [1:0]  trans;   // HTRANS

    // read response (filled by monitor)
    logic [31:0] rdata;
    logic        resp;         // HRESP

    // address constraints — target the 4 APB slave regions
    // slave 0: 0x4000_xxxx, slave 1: 0x4001_xxxx, etc.
    constraint c_addr_aligned {
        addr[1:0] == 2'b00;  // word-aligned only
        addr inside {
            [32'h4000_0000 : 32'h4000_FFFF],
            [32'h4001_0000 : 32'h4001_FFFF],
            [32'h4002_0000 : 32'h4002_FFFF],
            [32'h4003_0000 : 32'h4003_FFFF]
        };
    }

    constraint c_trans { trans == 2'b10; }  // NONSEQ only for now

    function new(string name = "ahb_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("ADDR=%08h DATA=%08h WRITE=%0b RESP=%0b",
                         addr, write ? data : rdata, write, resp);
    endfunction
endclass
