interface apb_if #(parameter ADDR_WIDTH=8, DATA_WIDTH=32) (input logic PCLK, input logic PRESETn);
  logic         PSEL;
  logic         PENABLE;
  logic         PWRITE;
  logic [ADDR_WIDTH-1:0] PADDR;
  logic [DATA_WIDTH-1:0] PWDATA;
  logic [DATA_WIDTH-1:0] PRDATA;
  logic         PREADY;

  // Clocking blocks for driver/monitor
  clocking drv_cb @(posedge PCLK);
    default input #1step output #1step;
    output PSEL, PENABLE, PWRITE, PADDR, PWDATA;
    input  PRDATA, PREADY;
  endclocking

  clocking mon_cb @(posedge PCLK);
    default input #1step output #1step;
    input PSEL, PENABLE, PWRITE, PADDR, PWDATA, PRDATA, PREADY;
  endclocking

  // Reset task for convenience
  task automatic apb_reset();
    PSEL    = 0;
    PENABLE = 0;
    PWRITE  = 0;
    PADDR   = '0;
    PWDATA  = '0;
  endtask

endinterface
