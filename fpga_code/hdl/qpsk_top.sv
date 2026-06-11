`timescale 1ns / 1ps

module qpsk_top #(
    parameter int MODE = 1,
    parameter bit LOW_RESOURCE = 1'b1
) (
    input  logic clk,
    input  logic rst_n,
    input  logic sample_en,
    input  logic symbol_valid,
    input  logic [1:0] bits_in,
    output logic signed [11:0] i_bb,
    output logic signed [11:0] q_bb,
    output logic signed [13:0] y_if,
    output logic out_valid
);

    generate
        if (LOW_RESOURCE) begin : gen_low_resource
            qpsk_tx_core_lowres core_u (
                .clk(clk),
                .rst_n(rst_n),
                .sample_en(sample_en),
                .symbol_valid(symbol_valid),
                .bits_in(bits_in),
                .i_bb(i_bb),
                .q_bb(q_bb),
                .y_if(y_if),
                .out_valid(out_valid)
            );
        end else begin : gen_full
            qpsk_tx_core #(.MODE(MODE)) core_u (
                .clk(clk),
                .rst_n(rst_n),
                .sample_en(sample_en),
                .symbol_valid(symbol_valid),
                .bits_in(bits_in),
                .i_bb(i_bb),
                .q_bb(q_bb),
                .y_if(y_if),
                .out_valid(out_valid)
            );
        end
    endgenerate

endmodule
