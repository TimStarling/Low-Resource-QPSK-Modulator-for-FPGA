`timescale 1ns / 1ps

module srrc_fir_complex_shiftadd #(
    parameter int IN_W = 12,
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

    logic signed [IN_W-1:0] i_shift [0:NTAPS-1];
    logic signed [IN_W-1:0] q_shift [0:NTAPS-1];
    logic signed [ACC_W-1:0] acc_i;
    logic signed [ACC_W-1:0] acc_q;
    logic signed [ACC_W-1:0] scaled_i;
    logic signed [ACC_W-1:0] scaled_q;

    integer k;

    function automatic logic signed [ACC_W-1:0] sx(input logic signed [IN_W:0] value);
        sx = {{(ACC_W-IN_W-1){value[IN_W]}}, value};
    endfunction

    function automatic logic signed [ACC_W-1:0] mul_sym_coef(
        input int idx,
        input logic signed [IN_W:0] value
    );
        logic signed [ACC_W-1:0] v;
        begin
            v = sx(value);
            unique case (idx)
                0:  mul_sym_coef = (v <<< 4) + (v <<< 2) + (v <<< 1);
                1:  mul_sym_coef = (v <<< 3) + (v <<< 1);
                2:  mul_sym_coef = -((v <<< 4) + (v <<< 1) + v);
                3:  mul_sym_coef = -((v <<< 5) + (v <<< 3) + (v <<< 2));
                4:  mul_sym_coef = -((v <<< 5) + (v <<< 2) + (v <<< 1));
                5:  mul_sym_coef = (v <<< 2) + (v <<< 1);
                6:  mul_sym_coef = (v <<< 6) + (v <<< 1) + v;
                7:  mul_sym_coef = (v <<< 6) + (v <<< 5);
                8:  mul_sym_coef = (v <<< 5) + (v <<< 4) + (v <<< 2) + (v <<< 1);
                9:  mul_sym_coef = -((v <<< 5) + (v <<< 4) + (v <<< 3));
                10: mul_sym_coef = -((v <<< 7) + (v <<< 5) + (v <<< 3) + (v <<< 2) + (v <<< 1));
                11: mul_sym_coef = -((v <<< 7) + (v <<< 6) + (v <<< 3) + (v <<< 1) + v);
                12: mul_sym_coef = -((v <<< 6) + (v <<< 1));
                13: mul_sym_coef = (v <<< 7) + (v <<< 6) + (v <<< 5) + (v <<< 4) + (v <<< 2);
                14: mul_sym_coef = (v <<< 9) + (v <<< 6) + (v <<< 5) + (v <<< 4) + (v <<< 3) + (v <<< 2) + v;
                15: mul_sym_coef = (v <<< 9) + (v <<< 8) + (v <<< 7) + (v <<< 6) + (v <<< 2) + (v <<< 1);
                default: mul_sym_coef = (v <<< 10) + (v <<< 6) + (v <<< 2) + (v <<< 1);
            endcase
        end
    endfunction

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
        acc_i = mul_sym_coef(16, {i_shift[16][IN_W-1], i_shift[16]});
        acc_q = mul_sym_coef(16, {q_shift[16][IN_W-1], q_shift[16]});
        for (int n = 0; n < 16; n = n + 1) begin
            logic signed [IN_W:0] pair_i;
            logic signed [IN_W:0] pair_q;
            pair_i = {i_shift[n][IN_W-1], i_shift[n]} + {i_shift[NTAPS-1-n][IN_W-1], i_shift[NTAPS-1-n]};
            pair_q = {q_shift[n][IN_W-1], q_shift[n]} + {q_shift[NTAPS-1-n][IN_W-1], q_shift[NTAPS-1-n]};
            acc_i += mul_sym_coef(n, pair_i);
            acc_q += mul_sym_coef(n, pair_q);
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
