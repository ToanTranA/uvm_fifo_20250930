
module apb_fifo_buggy #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 16,
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic         PCLK,
    input  logic         PRESETn,
    input  logic         PSEL,
    input  logic         PENABLE,
    input  logic         PWRITE,
    input  logic [7:0]   PADDR,
    input  logic [31:0]  PWDATA,
    output logic [31:0]  PRDATA,
    output logic         PREADY,

    input  logic         wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    input  logic         rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic         empty,
    output logic         full
);

    logic [DATA_WIDTH-1:0] fifo_mem [0:DEPTH-1];
    logic [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;
    logic [ADDR_WIDTH:0]   fifo_count;

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            wr_ptr     <= '0;
            rd_ptr     <= '0;
            fifo_count <= '0;
            rd_data    <= '0;
        end else begin
            if (wr_en && !full) begin
                fifo_mem[wr_ptr] <= wr_data;
                wr_ptr <= wr_ptr + 1'b1;
                fifo_count <= fifo_count + 1'b1;
            end
            if (rd_en && !empty) begin
                rd_data <= fifo_mem[rd_ptr];
                fifo_count <= fifo_count - 1'b1;
            end
        end
    end

    assign empty = (fifo_count == 0);
    assign full  = (fifo_count == DEPTH);

    logic [31:0] status_reg;
    logic [31:0] control_reg;

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            status_reg  <= 32'h0;
            control_reg <= 32'h0;
            PRDATA      <= 32'h0;
        end else if (PSEL && PENABLE) begin
            if (PWRITE) begin
                case (PADDR)
                    8'h00: control_reg <= PWDATA;
                    default: ;
                endcase
            end else begin
                case (PADDR)
                    8'h00: PRDATA <= control_reg;
                    8'h04: PRDATA <= {30'b0, full, empty};
                    default: PRDATA <= 32'hDEADBEEF;
                endcase
            end
        end
    end

    assign PREADY = 1'b1;
endmodule
