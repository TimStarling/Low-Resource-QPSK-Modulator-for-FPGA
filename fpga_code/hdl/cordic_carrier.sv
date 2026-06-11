`timescale 1ns / 1ps

module cordic_carrier #(
    parameter int PHASE_W = 18,
    parameter int AMP_W = 12,
    parameter int ITER = 12,
    parameter logic [PHASE_W-1:0] PHASE_INC = 18'd65536
) (
    input  logic clk,
    input  logic rst_n,
    input  logic sample_en,
    output logic signed [AMP_W-1:0] cos_o,
    output logic signed [AMP_W-1:0] sin_o
);

    localparam int signed K_GAIN = 1243;
    localparam logic signed [PHASE_W-1:0] ATAN [0:ITER-1] = '{
        18'sd32768, 18'sd19344, 18'sd10221, 18'sd5188,
        18'sd2604, 18'sd1303, 18'sd652, 18'sd326,
        18'sd163, 18'sd81, 18'sd41, 18'sd20
    };

    logic [PHASE_W-1:0] phase;
    logic signed [PHASE_W-1:0] z [0:ITER];
    logic signed [AMP_W+ITER:0] x [0:ITER];
    logic signed [AMP_W+ITER:0] y [0:ITER];
    logic signed [PHASE_W-1:0] z0;
    logic negate;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= '0;
        end else if (sample_en) begin
            phase <= phase + PHASE_INC;
        end
    end

    always_comb begin
        negate = 1'b0;
        if (phase[PHASE_W-1:PHASE_W-2] == 2'b01) begin
            z0 = $signed(phase - (1 << (PHASE_W-1)));
            negate = 1'b1;
        end else if (phase[PHASE_W-1:PHASE_W-2] == 2'b10) begin
            z0 = $signed(phase + (1 << (PHASE_W-1)));
            negate = 1'b1;
        end else begin
            z0 = $signed(phase);
        end

        x[0] = K_GAIN;
        y[0] = '0;
        z[0] = z0;

        for (int i = 0; i < ITER; i = i + 1) begin
            if (z[i] >= 0) begin
                x[i+1] = x[i] - (y[i] >>> i);
                y[i+1] = y[i] + (x[i] >>> i);
                z[i+1] = z[i] - ATAN[i];
            end else begin
                x[i+1] = x[i] + (y[i] >>> i);
                y[i+1] = y[i] - (x[i] >>> i);
                z[i+1] = z[i] + ATAN[i];
            end
        end

        if (negate) begin
            cos_o = -x[ITER][AMP_W-1:0];
            sin_o = -y[ITER][AMP_W-1:0];
        end else begin
            cos_o = x[ITER][AMP_W-1:0];
            sin_o = y[ITER][AMP_W-1:0];
        end
    end

endmodule
