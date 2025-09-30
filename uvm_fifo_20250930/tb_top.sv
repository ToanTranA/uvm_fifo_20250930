`timescale 1ns/1ps
`include "uvm_macros.svh"

import uvm_pkg::*;
import apb_pkg::*;
import fifo_pkg::*;
import env_pkg::*;
import tests_pkg::*;

// Include DUT
`define HAS_DUT 1

module tb_top;
  // Clock/Reset
  logic PCLK;
  logic PRESETn;

  // APB interface
  apb_if apb(PCLK, PRESETn);

  // DUT extra FIFO-side ports (based on compile warnings)
  logic        full, empty;
  logic  [7:0] rd_data;
  logic        rd_en;
  logic  [7:0] wr_data;
  logic        wr_en;

`ifdef HAS_DUT
  // Instantiate DUT (ports inferred from provided file)
  apb_fifo_buggy #(.DATA_WIDTH(8), .DEPTH(16)) dut (
    .PCLK   (PCLK),
    .PRESETn(PRESETn),
    .PSEL   (apb.PSEL),
    .PENABLE(apb.PENABLE),
    .PWRITE (apb.PWRITE),
    .PADDR  (apb.PADDR),
    .PWDATA (apb.PWDATA),
    .PRDATA (apb.PRDATA),
    .PREADY (apb.PREADY),
    // Extra FIFO-side ports
    .full   (full),
    .empty  (empty),
    .rd_data(rd_data),
    .rd_en  (rd_en),
    .wr_data(wr_data),
    .wr_en  (wr_en)
  );
`endif

  // Default drive for external FIFO ports (kept idle unless you want to poke them)
  assign rd_en  = 1'b0;
  assign wr_en  = 1'b0;
  assign wr_data= '0;

  // Clock gen
  initial begin
    PCLK = 0;
    forever #5 PCLK = ~PCLK; // 100 MHz
  end

  // Reset
  initial begin
    PRESETn = 0;
    apb.apb_reset();
    repeat (5) @(posedge PCLK);
    PRESETn = 1;
  end

  // UVM run
  initial begin
    string testname; // declare before any statements

    // Provide virtual interface to UVM
    uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top.env.apb_agent*", "vif", apb);
    uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top.env.fifo_agent*", "vif", apb); // FIFO agent is passive, taps APB

    if (!$value$plusargs("UVM_TESTNAME=%s", testname))
      testname = "apb_fifo_base_test";

    run_test(testname);
  end

endmodule
