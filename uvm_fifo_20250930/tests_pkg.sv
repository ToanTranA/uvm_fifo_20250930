package tests_pkg;
  import uvm_pkg::*;
  import apb_pkg::*;
  import env_pkg::*;
  `include "uvm_macros.svh"

  // Base sequence with a simple shadow model of FIFO depth using status bits.
  class fifo_model_seq extends uvm_sequence#(apb_seq_item);
    `uvm_object_utils(fifo_model_seq)

    // Assumptions:
    // - STATUS register at 0x04
    // - bit[0] = EMPTY, bit[1] = FULL
    // - PUSH at 0x10, POP at 0x14, data @ push is low 8b of PWDATA
    localparam int DEPTH = 16;

    int count; // shadow occupancy

    function new(string name="fifo_model_seq"); super.new(name); endfunction

    // APB helpers
    virtual task apb_write(byte addr, int unsigned data);
      apb_seq_item t; `uvm_create(t)
      t.cmd  = APB_WRITE; t.addr = addr; t.data = data;
      start_item(t); finish_item(t);
    endtask

    virtual task apb_read(byte addr, output int unsigned data);
      apb_seq_item t; `uvm_create(t)
      t.cmd  = APB_READ; t.addr = addr;
      start_item(t); finish_item(t);
      data = t.rdata;
    endtask

    virtual task read_status(output bit empty, output bit full);
      int unsigned s; empty = 0; full = 0;
      apb_read(8'h04, s);
      empty = s[0];
      full  = s[1];
      `uvm_info(get_type_name(), $sformatf("STATUS read: 0x%0h (E=%0b F=%0b) count=%0d", s, empty, full, count), UVM_MEDIUM)
    endtask

    // Model updates + checks
    virtual task do_push(byte data);
      bit e, f;
      apb_write(8'h10, data);
      if (count < DEPTH) count++;
      read_status(e,f);
      if (count==0 && !e) `uvm_error("CHK", "Expected EMPTY=1 when count==0")
      if (count>0 && e)   `uvm_error("CHK", "EMPTY stuck high")
      if (count==DEPTH && !f) `uvm_error("CHK", "Expected FULL=1 at capacity")
      if (count<DEPTH && f)   `uvm_warning("CHK", "FULL asserted before capacity")
    endtask

    virtual task do_pop();
      bit e, f;
      apb_write(8'h14, 32'h0);
      if (count > 0) count--;
      read_status(e,f);
      if (count==0 && !e) `uvm_error("CHK", "Expected EMPTY=1 after draining to zero")
      if (count<DEPTH && f) `uvm_error("CHK", "FULL stuck high after pop")
    endtask

    virtual task pre_body();
      bit e,f;
      count = 0;
      // sync status once
      read_status(e,f);
      if (!e) `uvm_warning("INIT", "DUT reports non-empty at start");
    endtask
  endclass

  // 1) Overflow attempt: push DEPTH+2, then read status
  class overflow_seq extends fifo_model_seq;
    `uvm_object_utils(overflow_seq)
    function new(string name="overflow_seq"); super.new(name); endfunction
    virtual task body();
      int i;
      for (i=0; i<DEPTH+2; i++) begin
        byte d = i[7:0];
        do_push(d);
      end
    endtask
  endclass

  // 2) Underflow attempt: pop 4 from empty, then push 1 and pop 1
  class underflow_seq extends fifo_model_seq;
    `uvm_object_utils(underflow_seq)
    function new(string name="underflow_seq"); super.new(name); endfunction
    virtual task body();
      repeat (4) do_pop();       // expect graceful underflow handling
      do_push(8'hAA);
      do_pop();
    endtask
  endclass

  // 3) Random stress: randomized pushes/pops with random gaps
  class rand_stress_seq extends fifo_model_seq;
    `uvm_object_utils(rand_stress_seq)
    rand int unsigned n_ops;
    constraint c_ops { n_ops inside {[100:300]}; }
    function new(string name="rand_stress_seq"); super.new(name); endfunction
    virtual task body();
      bit choose_push;
      for (int i=0; i<n_ops; i++) begin
        void'(std::randomize(choose_push));
        if (choose_push) do_push($urandom_range(0,255));
        else             do_pop();
        // small random idle
        repeat ($urandom_range(0,3)) #1;
      end
    endtask
  endclass

  // ---------- Tests ----------

  class apb_fifo_overflow_test extends uvm_test;
    `uvm_component_utils(apb_fifo_overflow_test)
    apb_env env;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      env = apb_env::type_id::create("env", this);
    endfunction
    task run_phase(uvm_phase phase);
      overflow_seq seq = overflow_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.apb_agent_h.sqr);
      phase.drop_objection(this);
    endtask
  endclass

  class apb_fifo_underflow_test extends uvm_test;
    `uvm_component_utils(apb_fifo_underflow_test)
    apb_env env;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      env = apb_env::type_id::create("env", this);
    endfunction
    task run_phase(uvm_phase phase);
      underflow_seq seq = underflow_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.apb_agent_h.sqr);
      phase.drop_objection(this);
    endtask
  endclass

  class apb_fifo_stress_test extends uvm_test;
    `uvm_component_utils(apb_fifo_stress_test)
    apb_env env;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      env = apb_env::type_id::create("env", this);
    endfunction
    task run_phase(uvm_phase phase);
      rand_stress_seq seq = rand_stress_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.apb_agent_h.sqr);
      phase.drop_objection(this);
    endtask
  endclass

endpackage
