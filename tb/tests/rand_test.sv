// Random test — 500 constrained-random AHB transfers
// Mix of reads and writes across all 4 APB slave regions

class rand_sequence extends uvm_sequence #(ahb_seq_item);
    `uvm_object_utils(rand_sequence)

    int unsigned num_txns = 500;

    function new(string name = "rand_sequence");
        super.new(name);
    endfunction

    task body();
        ahb_seq_item txn;
        repeat (num_txns) begin
            txn = ahb_seq_item::type_id::create("txn");
            start_item(txn);
            if (!txn.randomize())
                `uvm_fatal("RAND", "randomization failed")
            finish_item(txn);
        end
    endtask
endclass


class rand_test extends uvm_test;
    `uvm_component_utils(rand_test)

    ahb_apb_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = ahb_apb_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        rand_sequence seq;
        phase.raise_objection(this);
        seq = rand_sequence::type_id::create("seq");
        seq.start(env.ahb_agent.sequencer);
        #100;
        phase.drop_objection(this);
    endtask
endclass
