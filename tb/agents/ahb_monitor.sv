// AHB Monitor — observes bus and broadcasts to scoreboard + coverage
// passive — doesn't drive anything

class ahb_monitor extends uvm_monitor;
    `uvm_component_utils(ahb_monitor)

    virtual ahb_apb_if    vif;
    uvm_analysis_port #(ahb_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual ahb_apb_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "AHB monitor: no interface found")
    endfunction

    task run_phase(uvm_phase phase);
        ahb_seq_item txn;
        @(posedge vif.HRESETn);

        forever begin
            // wait for a valid non-idle AHB transfer
            @(posedge vif.HCLK);
            if (vif.HSEL && vif.HREADY && vif.HTRANS == 2'b10) begin
                txn = ahb_seq_item::type_id::create("txn");
                txn.addr  = vif.HADDR;
                txn.write = vif.HWRITE;
                txn.trans = vif.HTRANS;

                // wait for data phase to complete
                do @(posedge vif.HCLK); while (!vif.HREADY);
                txn.data  = vif.HWDATA;
                txn.rdata = vif.HRDATA;
                txn.resp  = vif.HRESP;

                ap.write(txn);
            end
        end
    endtask
endclass
