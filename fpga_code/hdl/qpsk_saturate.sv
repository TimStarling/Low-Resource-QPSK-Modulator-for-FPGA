`timescale 1ns / 1ps

module qpsk_saturate #(
    parameter int IN_W = 32,
    parameter int OUT_W = 12
) (
    input  logic signed [IN_W-1:0] in_data,
    output logic signed [OUT_W-1:0] out_data
);

    localparam logic signed [IN_W-1:0] MAX_VAL = (1 <<< (OUT_W - 1)) - 1;
    localparam logic signed [IN_W-1:0] MIN_VAL = -(1 <<< (OUT_W - 1));

    always_comb begin
        if (in_data > MAX_VAL) begin
            out_data = MAX_VAL[OUT_W-1:0];
        end else if (in_data < MIN_VAL) begin
            out_data = MIN_VAL[OUT_W-1:0];
        end else begin
            out_data = in_data[OUT_W-1:0];
        end
    end

endmodule
