// Functional coverage for AHB-APB bridge
// Saras Chandra Kannam

class ahb_apb_coverage extends uvm_subscriber #(ahb_seq_item);
    `uvm_component_utils(ahb_apb_coverage)

    ahb_seq_item txn;

    // cover all 4 slave regions, read and write
    covergroup bridge_cg;
        cp_slave: coverpoint txn.addr[17:16] {
            bins slave0 = {2'b00};
            bins slave1 = {2'b01};
            bins slave2 = {2'b10};
            bins slave3 = {2'b11};
        }
        cp_write: coverpoint txn.write {
            bins read  = {1'b0};
            bins write = {1'b1};
        }
        // cross: each slave exercised with both read and write
        cx_slave_rw: cross cp_slave, cp_write;

        // response types
        cp_resp: coverpoint txn.resp {
            bins okay  = {1'b0};
            bins error = {1'b1};
        }

        // address alignment (should always be word-aligned, but check)
        cp_align: coverpoint txn.addr[1:0] {
            bins aligned   = {2'b00};
            bins unaligned = {[2'b01:2'b11]};
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        bridge_cg = new();
    endfunction

    function void write(ahb_seq_item t);
        txn = t;
        bridge_cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("COV", $sformatf("Bridge coverage: %.1f%%",
                                    bridge_cg.get_coverage()), UVM_LOW)
    endfunction
endclass
