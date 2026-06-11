`timescale 1ns / 1ps

module qpsk_tx_core #(
    parameter int MODE = 1,       // 0 BASEBAND, 1 FS4_IF, 2 DDS_IF, 3 CORDIC_IF
    parameter int DATA_W = 12,
    parameter int IF_W = 14
) (
    input  logic clk,
    input  logic rst_n,
    input  logic sample_en,
    input  logic symbol_valid,
    input  logic [1:0] bits_in,
    output logic signed [DATA_W-1:0] i_bb,
    output logic signed [DATA_W-1:0] q_bb,
    output logic signed [IF_W-1:0] y_if,
    output logic out_valid
);

    logic signed [DATA_W-1:0] map_i;
    logic signed [DATA_W-1:0] map_q;
    logic signed [DATA_W-1:0] fir_i_in;
    logic signed [DATA_W-1:0] fir_q_in;
    logic fir_valid;
    logic [1:0] fs4_phase;

    logic signed [DATA_W-1:0] dds_cos;
    logic signed [DATA_W-1:0] dds_sin;
    logic signed [DATA_W-1:0] cordic_cos;
    logic signed [DATA_W-1:0] cordic_sin;
    logic signed [IF_W-1:0] dds_y;
    logic signed [IF_W-1:0] cordic_y;

    qpsk_mapper #(.OUT_W(DATA_W), .AMP(1448)) mapper_u (
        .bits_in(bits_in),
        .i_sym(map_i),
        .q_sym(map_q)
    );

    always_comb begin
        fir_i_in = (symbol_valid && sample_en) ? map_i : '0;
        fir_q_in = (symbol_valid && sample_en) ? map_q : '0;
    end

    srrc_fir_complex #(.IN_W(DATA_W), .OUT_W(DATA_W)) fir_u (
        .clk(clk),
        .rst_n(rst_n),
        .sample_en(sample_en),
        .i_in(fir_i_in),
        .q_in(fir_q_in),
        .i_out(i_bb),
        .q_out(q_bb),
        .out_valid(fir_valid)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fs4_phase <= 2'd0;
        end else if (sample_en) begin
            fs4_phase <= fs4_phase + 2'd1;
        end
    end

    dds_carrier dds_u (
        .clk(clk),
        .rst_n(rst_n),
        .sample_en(sample_en),
        .cos_o(dds_cos),
        .sin_o(dds_sin)
    );

    cordic_carrier cordic_u (
        .clk(clk),
        .rst_n(rst_n),
        .sample_en(sample_en),
        .cos_o(cordic_cos),
        .sin_o(cordic_sin)
    );

    qpsk_if_mixer #(.IN_W(DATA_W), .C_W(DATA_W), .OUT_W(IF_W)) dds_mixer_u (
        .i_in(i_bb),
        .q_in(q_bb),
        .cos_i(dds_cos),
        .sin_i(dds_sin),
        .y_out(dds_y)
    );

    qpsk_if_mixer #(.IN_W(DATA_W), .C_W(DATA_W), .OUT_W(IF_W)) cordic_mixer_u (
        .i_in(i_bb),
        .q_in(q_bb),
        .cos_i(cordic_cos),
        .sin_i(cordic_sin),
        .y_out(cordic_y)
    );

    always_comb begin
        unique case (MODE)
            0: y_if = {{(IF_W-DATA_W){i_bb[DATA_W-1]}}, i_bb};
            1: begin
                unique case (fs4_phase)
                    2'd0: y_if = {{(IF_W-DATA_W){i_bb[DATA_W-1]}}, i_bb};
                    2'd1: y_if = -{{(IF_W-DATA_W){q_bb[DATA_W-1]}}, q_bb};
                    2'd2: y_if = -{{(IF_W-DATA_W){i_bb[DATA_W-1]}}, i_bb};
                    default: y_if = {{(IF_W-DATA_W){q_bb[DATA_W-1]}}, q_bb};
                endcase
            end
            2: y_if = dds_y;
            3: y_if = cordic_y;
            default: y_if = '0;
        endcase
    end

    assign out_valid = fir_valid;

endmodule
