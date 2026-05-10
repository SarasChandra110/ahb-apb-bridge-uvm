// Scoreboard — checks AHB transactions against APB-side observations
// Two analysis ports: one from AHB monitor, one from APB monitor
// Write: check that PADDR/PWDATA/PWRITE match what AHB sent
// Read:  check that HRDATA matches PRDATA from APB slave

class ahb_apb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(ahb_apb_scoreboard)

    uvm_analysis_imp_ahb #(ahb_seq_item, ahb_apb_scoreboard) ahb_export;
    uvm_analysis_imp_apb #(apb_seq_item, ahb_apb_scoreboard) apb_export;

    // simple queues — match AHB txns to corresponding APB txns
    ahb_seq_item ahb_q[$];
    apb_seq_item apb_q[$];

    int pass_cnt, fail_cnt;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ahb_export = new("ahb_export", this);
        apb_export = new("apb_export", this);
    endfunction

    // called when AHB monitor observes a transaction
    function void write_ahb(ahb_seq_item txn);
        ahb_q.push_back(txn);
        try_check();
    endfunction

    // called when APB monitor observes a transaction
    function void write_apb(apb_seq_item txn);
        apb_q.push_back(txn);
        try_check();
    endfunction

    function void try_check();
        if (ahb_q.size() == 0 || apb_q.size() == 0) return;

        ahb_seq_item ahb_txn = ahb_q.pop_front();
        apb_seq_item apb_txn = apb_q.pop_front();

        // address must match
        if (ahb_txn.addr !== apb_txn.paddr) begin
            `uvm_error("SB", $sformatf("ADDR mismatch: AHB=%08h APB=%08h",
                                        ahb_txn.addr, apb_txn.paddr))
            fail_cnt++;
            return;
        end

        // direction must match
        if (ahb_txn.write !== apb_txn.pwrite) begin
            `uvm_error("SB", $sformatf("WRITE mismatch: AHB=%0b APB=%0b",
                                        ahb_txn.write, apb_txn.pwrite))
            fail_cnt++;
            return;
        end

        // write: check data propagated correctly
        if (ahb_txn.write && ahb_txn.data !== apb_txn.pwdata) begin
            `uvm_error("SB", $sformatf("WDATA mismatch: AHB=%08h APB=%08h",
                                        ahb_txn.data, apb_txn.pwdata))
            fail_cnt++;
            return;
        end

        // read: check HRDATA == PRDATA
        if (!ahb_txn.write && ahb_txn.rdata !== apb_txn.prdata) begin
            `uvm_error("SB", $sformatf("RDATA mismatch: HRDATA=%08h PRDATA=%08h",
                                        ahb_txn.rdata, apb_txn.prdata))
            fail_cnt++;
            return;
        end

        pass_cnt++;
        `uvm_info("SB", $sformatf("PASS: %s", ahb_txn.convert2string()), UVM_HIGH)
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SB", $sformatf("SCOREBOARD: %0d passed, %0d failed",
                                   pass_cnt, fail_cnt), UVM_LOW)
        if (fail_cnt > 0)
            `uvm_error("SB", "TEST FAILED — scoreboard mismatches detected")
    endfunction
endclass
