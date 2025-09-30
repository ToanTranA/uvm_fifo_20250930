package env_pkg;
  import uvm_pkg::*;
  import apb_pkg::*;
  import fifo_pkg::*;
  `include "uvm_macros.svh"

  // Declare distinct analysis_imps so we can have two write methods
  `uvm_analysis_imp_decl(_apb)
  `uvm_analysis_imp_decl(_fifo)

  class scoreboard extends uvm_component;
    `uvm_component_utils(scoreboard)

    // Two independent analysis imps
    uvm_analysis_imp_apb #(apb_seq_item, scoreboard) apb_exp;
    uvm_analysis_imp_fifo #(fifo_item,    scoreboard) fifo_exp;

    bit [31:0] last_status;
    int pushes, pops;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      apb_exp  = new("apb_exp",  this);
      fifo_exp = new("fifo_exp", this);
    endfunction

    // Callback for APB transactions
    function void write_apb(apb_seq_item t);
      // pragma coverage off
      if (t.cmd==APB_READ && t.addr==8'h04) begin
        last_status = t.rdata;
        `uvm_info("SCB", $sformatf("Read STATUS=0x%08h", t.rdata), UVM_LOW)
      end
      // pragma coverage on
    endfunction

    // Callback for FIFO events
    function void write_fifo(fifo_item f);
      // pragma coverage off
      case (f.kind)
        FIFO_PUSH: pushes++;
        FIFO_POP:  pops++;
        FIFO_STATUS: last_status = f.status;
      endcase
      `uvm_info("SCB", $sformatf("FIFO evt %s, pushes=%0d pops=%0d",
                f.kind.name(), pushes, pops), UVM_LOW)
      // pragma coverage on
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("SCB", $sformatf("Final pushes=%0d pops=%0d status=0x%08h", pushes, pops, last_status), UVM_NONE)
    endfunction
  endclass

  // Rename env class to avoid any parsing ambiguity
  class apb_env extends uvm_env;
    `uvm_component_utils(apb_env)
    apb_agent  apb_agent_h;
    fifo_agent fifo_agent_h;
    scoreboard scb;

    function new(string name, uvm_component parent); super.new(name,parent); endfunction

    function void build_phase(uvm_phase phase);
      apb_agent_h  = apb_agent ::type_id::create("apb_agent", this);
      fifo_agent_h = fifo_agent::type_id::create("fifo_agent", this);
      scb          = scoreboard::type_id::create("scb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      // Tap APB monitor into scoreboard and FIFO agent
      apb_agent_h.mon.ap.connect(scb.apb_exp);
      apb_agent_h.mon.ap.connect(fifo_agent_h.mon.apb_imp);
      fifo_agent_h.mon.ap.connect(scb.fifo_exp);
    endfunction
  endclass

  // Simple smoke sequence (unchanged)
  class smoke_seq extends uvm_sequence#(apb_seq_item);
    `uvm_object_utils(smoke_seq)
    rand int unsigned n_ops = 16;
    function new(string name="smoke_seq"); super.new(name); endfunction

    virtual task body();
      apb_seq_item t;
      bit [31:0] r;
      `uvm_do_with(t, {cmd==APB_WRITE; addr==8'h00; data==32'hA5A5_0001;})
      `uvm_do_with(t, {cmd==APB_READ; addr==8'h04;}) r = t.rdata;
      `uvm_info("SMOKE", $sformatf("STATUS: 0x%08h", r), UVM_LOW)
      repeat (n_ops/2) begin
        `uvm_do_with(t, {cmd==APB_WRITE; addr==8'h10; data inside {[0:255]};})
      end
      repeat (n_ops/2) begin
        `uvm_do_with(t, {cmd==APB_WRITE; addr==8'h14; data==32'h0;})
      end
      `uvm_do_with(t, {cmd==APB_READ; addr==8'h04;}) r = t.rdata;
      `uvm_info("SMOKE", $sformatf("Final STATUS: 0x%08h", r), UVM_LOW)
    endtask
  endclass

  class apb_fifo_base_test extends uvm_test;
    `uvm_component_utils(apb_fifo_base_test)
    apb_env env; // instance will be named "env"
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      env = apb_env::type_id::create("env", this);
    endfunction
    task run_phase(uvm_phase phase);
      smoke_seq seq = smoke_seq::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.apb_agent_h.sqr);
      phase.drop_objection(this);
    endtask
  endclass

endpackage
