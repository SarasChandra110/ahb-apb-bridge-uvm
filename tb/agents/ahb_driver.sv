// AHB Master Driver
// drives AHB transactions onto the interface

class ahb_driver extends uvm_driver #(ahb_seq_item);
    `uvm_component_utils(ahb_driver)

    virtual ahb_apb_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual ahb_apb_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "AHB driver: no interface found in config db")
    endfunction

    task run_phase(uvm_phase phase);
        ahb_seq_item txn;
        // idle the bus at reset
        vif.HSEL   <= 0;
        vif.HTRANS <= 2'b00;
        vif.HWRITE <= 0;
        vif.HADDR  <= 0;
        vif.HWDATA <= 0;
        @(posedge vif.HRESETn);
        @(posedge vif.HCLK);

        forever begin
            seq_item_port.get_next_item(txn);
            drive(txn);
            seq_item_port.item_done();
        end
    endtask

    task drive(ahb_seq_item txn);
        // address phase
        @(posedge vif.HCLK);
        vif.HSEL   <= 1;
        vif.HTRANS <= txn.trans;
        vif.HWRITE <= txn.write;
        vif.HADDR  <= txn.addr;

        // wait for HREADY (slave might insert wait states)
        do @(posedge vif.HCLK); while (!vif.HREADY);

        // data phase — drive write data or let read complete
        vif.HWDATA <= txn.data;
        vif.HTRANS <= 2'b00;  // back to IDLE
        vif.HSEL   <= 0;

        // wait for HREADY to confirm transfer complete
        do @(posedge vif.HCLK); while (!vif.HREADY);

        // capture read data
        if (!txn.write) begin
            txn.rdata = vif.HRDATA;
            txn.resp  = vif.HRESP;
        end
    endtask
endclass
