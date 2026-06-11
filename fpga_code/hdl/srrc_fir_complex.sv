`timescale 1ns / 1ps

module srrc_fir_complex #(
    parameter int IN_W = 12,
    parameter int COEF_W = 12,
    parameter int OUT_W = 12,
    parameter int ACC_W = 36,
    parameter int NTAPS = 33,
    parameter int COEF_FRAC = 11
) (
    input  logic clk,
    input  logic rst_n,
    input  logic sample_en,
    input  logic signed [IN_W-1:0] i_in,
    input  logic signed [IN_W-1:0] q_in,
    output logic signed [OUT_W-1:0] i_out,
    output logic signed [OUT_W-1:0] q_out,
    output logic out_valid
);

    localparam logic signed [COEF_W-1:0] COEF [0:NTAPS-1] = '{
        12'sd22,  12'sd10, -12'sd19, -12'sd44, -12'sd38,  12'sd6,
        12'sd67,  12'sd96,  12'sd54, -12'sd56, -12'sd174, -12'sd203,
       -12'sd66, 12'sd244, 12'sd637, 12'sd966, 12'sd1094, 12'sd966,
       12'sd637, 12'sd244, -12'sd66, -12'sd203, -12'sd174, -12'sd56,
        12'sd54,  12'sd96,  12'sd67,  12'sd6, -12'sd38, -12'sd44,
       -12'sd19,  12'sd10,  12'sd22
    };

    logic signed [IN_W-1:0] i_shift [0:NTAPS-1];
    logic signed [IN_W-1:0] q_shift [0:NTAPS-1];
    logic signed [ACC_W-1:0] acc_i;
    logic signed [ACC_W-1:0] acc_q;
    logic signed [ACC_W-1:0] scaled_i;
    logic signed [ACC_W-1:0] scaled_q;

    integer k;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < NTAPS; k = k + 1) begin
                i_shift[k] <= '0;
                q_shift[k] <= '0;
            end
            out_valid <= 1'b0;
        end else if (sample_en) begin
            i_shift[0] <= i_in;
            q_shift[0] <= q_in;
            for (k = 1; k < NTAPS; k = k + 1) begin
                i_shift[k] <= i_shift[k-1];
                q_shift[k] <= q_shift[k-1];
            end
            out_valid <= 1'b1;
        end else begin
            out_valid <= 1'b0;
        end
    end

    always_comb begin
        acc_i = '0;
        acc_q = '0;
        for (int n = 0; n < NTAPS; n = n + 1) begin
            acc_i += i_shift[n] * COEF[n];
            acc_q += q_shift[n] * COEF[n];
        end
        scaled_i = acc_i >>> COEF_FRAC;
        scaled_q = acc_q >>> COEF_FRAC;
    end

    qpsk_saturate #(.IN_W(ACC_W), .OUT_W(OUT_W)) sat_i (
        .in_data(scaled_i),
        .out_data(i_out)
    );

    qpsk_saturate #(.IN_W(ACC_W), .OUT_W(OUT_W)) sat_q (
        .in_data(scaled_q),
        .out_data(q_out)
    );

endmodule
