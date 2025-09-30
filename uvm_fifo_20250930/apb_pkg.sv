package apb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  typedef enum {APB_READ, APB_WRITE} apb_cmd_e;

  class apb_seq_item extends uvm_sequence_item;
    rand apb_cmd_e cmd;
    rand bit [7:0] addr;
    rand bit [31:0] data;
         bit [31:0] rdata;
    `uvm_object_utils_begin(apb_seq_item)
      `uvm_field_enum(apb_cmd_e, cmd, UVM_ALL_ON)
      `uvm_field_int(addr, UVM_ALL_ON)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_int(rdata, UVM_NOPRINT)
    `uvm_object_utils_end
    function new(string name="apb_seq_item"); super.new(name); endfunction
  endclass

  class apb_driver extends uvm_driver#(apb_seq_item);
    `uvm_component_utils(apb_driver)
    virtual apb_if vif;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      if(!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
        `uvm_fatal(get_type_name(), "No virtual interface set for apb_driver")
    endfunction

    // Simple APB3: 2-phase transfer (SETUP then ACCESS)
    task automatic apb_write(bit [7:0] addr, bit [31:0] data);
      @(posedge vif.PCLK);
      vif.drv_cb.PADDR  <= addr;
      vif.drv_cb.PWDATA <= data;
      vif.drv_cb.PWRITE <= 1'b1;
      vif.drv_cb.PSEL   <= 1'b1;
      vif.drv_cb.PENABLE<= 1'b0;
      @(posedge vif.PCLK);
      vif.drv_cb.PENABLE<= 1'b1;
      // Wait for ready (DUT ties high per provided file)
      do @(posedge vif.PCLK); while (!vif.PREADY);
      // Deassert
      vif.drv_cb.PSEL   <= 1'b0;
      vif.drv_cb.PENABLE<= 1'b0;
      vif.drv_cb.PWRITE <= 1'b0;
    endtask

    task automatic apb_read(bit [7:0] addr, output bit [31:0] rdata);
      @(posedge vif.PCLK);
      vif.drv_cb.PADDR  <= addr;
      vif.drv_cb.PWRITE <= 1'b0;
      vif.drv_cb.PSEL   <= 1'b1;
      vif.drv_cb.PENABLE<= 1'b0;
      @(posedge vif.PCLK);
      vif.drv_cb.PENABLE<= 1'b1;
      do @(posedge vif.PCLK); while (!vif.PREADY);
      rdata = vif.PRDATA;
      vif.drv_cb.PSEL   <= 1'b0;
      vif.drv_cb.PENABLE<= 1'b0;
    endtask

    task run_phase(uvm_phase phase);
      apb_seq_item tr;
      forever begin
        seq_item_port.get_next_item(tr);
        case (tr.cmd)
          APB_WRITE: apb_write(tr.addr, tr.data);
          APB_READ:  apb_read(tr.addr, tr.rdata);
        endcase
        seq_item_port.item_done();
      end
    endtask
  endclass

  class apb_monitor extends uvm_component;
    `uvm_component_utils(apb_monitor)
    virtual apb_if vif;
    uvm_analysis_port#(apb_seq_item) ap;
    function new(string name, uvm_component parent); super.new(name,parent); ap=new("ap", this); endfunction
    function void build_phase(uvm_phase phase);
      if(!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
        `uvm_fatal(get_type_name(), "No virtual interface set for apb_monitor")
    endfunction
    task run_phase(uvm_phase phase);
      apb_seq_item tx;
      tx = new();
      forever begin
        @(posedge vif.PCLK);
        if (vif.mon_cb.PSEL && vif.mon_cb.PENABLE) begin
          tx = new();
          tx.addr = vif.mon_cb.PADDR;
          if (vif.mon_cb.PWRITE) begin
            tx.cmd  = APB_WRITE;
            tx.data = vif.mon_cb.PWDATA;
          end else begin
            tx.cmd  = APB_READ;
            tx.rdata= vif.mon_cb.PRDATA;
          end
          ap.write(tx);
        end
      end
    endtask
  endclass

  class apb_sequencer extends uvm_sequencer#(apb_seq_item);
    `uvm_component_utils(apb_sequencer)
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
  endclass

  class apb_agent extends uvm_component;
    `uvm_component_utils(apb_agent)
    uvm_active_passive_enum is_active = UVM_ACTIVE;
    virtual apb_if vif;
    apb_sequencer sqr;
    apb_driver    drv;
    apb_monitor   mon;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      if(!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
        `uvm_fatal(get_type_name(), "No virtual interface set for apb_agent")
      void'(uvm_config_db#(uvm_active_passive_enum)::get(this, "", "is_active", is_active));
      mon = apb_monitor::type_id::create("mon", this);
      if (is_active == UVM_ACTIVE) begin
        sqr = apb_sequencer::type_id::create("sqr", this);
        drv = apb_driver   ::type_id::create("drv", this);
      end
    endfunction
    function void connect_phase(uvm_phase phase);
      if (is_active == UVM_ACTIVE) begin
        drv.vif = vif;
        mon.vif = vif;
        drv.seq_item_port.connect(sqr.seq_item_export);
      end else begin
        mon.vif = vif;
      end
    endfunction
  endclass

endpackage
