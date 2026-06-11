`timescale 1ns / 1ps

module qpsk_if_mixer #(
    parameter int IN_W = 12,
    parameter int C_W = 12,
    parameter int OUT_W = 14,
    parameter int ACC_W = 32,
    parameter int C_FRAC = 11
) (
    input  logic signed [IN_W-1:0] i_in,
    input  logic signed [IN_W-1:0] q_in,
    input  logic signed [C_W-1:0] cos_i,
    input  logic signed [C_W-1:0] sin_i,
    output logic signed [OUT_W-1:0] y_out
);

    logic signed [ACC_W-1:0] mixed;
    logic signed [ACC_W-1:0] scaled;

    always_comb begin
        mixed = i_in * cos_i - q_in * sin_i;
        scaled = mixed >>> C_FRAC;
    end

    qpsk_saturate #(.IN_W(ACC_W), .OUT_W(OUT_W)) sat_y (
        .in_data(scaled),
        .out_data(y_out)
    );

endmodule
