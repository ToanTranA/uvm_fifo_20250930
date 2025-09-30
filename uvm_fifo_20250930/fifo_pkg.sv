package fifo_pkg;
  import uvm_pkg::*;
  import apb_pkg::*;
  `include "uvm_macros.svh"

  // We'll receive APB transactions via an analysis_imp with a unique suffix
  `uvm_analysis_imp_decl(_from_apb)

  typedef enum {FIFO_PUSH, FIFO_POP, FIFO_STATUS} fifo_event_e;

  class fifo_item extends uvm_sequence_item;
    fifo_event_e kind;
    bit [7:0] addr;
    bit [31:0] data;
    bit [31:0] status;
    `uvm_object_utils_begin(fifo_item)
      `uvm_field_enum(fifo_event_e, kind, UVM_ALL_ON)
      `uvm_field_int(addr, UVM_ALL_ON)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_int(status, UVM_ALL_ON)
    `uvm_object_utils_end
    function new(string name="fifo_item"); super.new(name); endfunction
  endclass

  class fifo_monitor extends uvm_component;
    `uvm_component_utils(fifo_monitor)
    virtual apb_if vif;

    // Implementor to receive apb_seq_item
    uvm_analysis_imp_from_apb #(apb_seq_item, fifo_monitor) apb_imp;

    uvm_analysis_port #(fifo_item)     ap;

    // Address map (configurable)
    bit [7:0] ADDR_CTRL  = 8'h00;
    bit [7:0] ADDR_STAT  = 8'h04;
    bit [7:0] ADDR_PUSH  = 8'h10;
    bit [7:0] ADDR_POP   = 8'h14;

    function new(string name, uvm_component parent);
      super.new(name,parent);
      ap  = new("ap", this);
      apb_imp = new("apb_imp", this);
    endfunction

    // The analysis_imp callback from APB monitor
    function void write_from_apb(apb_seq_item t);
      fifo_item fi = new();
      fi.addr = t.addr;
      case (t.addr)
        8'h10: begin fi.kind = FIFO_PUSH; fi.data = t.data; end
        8'h14: begin fi.kind = FIFO_POP;  end
        8'h04: begin fi.kind = FIFO_STATUS; fi.status = t.rdata; end
        default: return;
      endcase
      ap.write(fi);
    endfunction

    function void build_phase(uvm_phase phase);
      void'(uvm_config_db#(byte)::get(this, "", "ADDR_CTRL", ADDR_CTRL));
      void'(uvm_config_db#(byte)::get(this, "", "ADDR_STAT", ADDR_STAT));
      void'(uvm_config_db#(byte)::get(this, "", "ADDR_PUSH", ADDR_PUSH));
      void'(uvm_config_db#(byte)::get(this, "", "ADDR_POP",  ADDR_POP));
      void'(uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif));
    endfunction
  endclass

  class fifo_agent extends uvm_component;
    `uvm_component_utils(fifo_agent)
    fifo_monitor mon;
    virtual apb_if vif;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      mon = fifo_monitor::type_id::create("mon", this);
      if(!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
        `uvm_fatal(get_type_name(), "No virtual interface for fifo_agent")
      mon.vif = vif;
    endfunction
  endclass

endpackage
