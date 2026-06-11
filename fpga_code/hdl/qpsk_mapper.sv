`timescale 1ns / 1ps

module qpsk_mapper #(
    parameter int OUT_W = 12,
    parameter int AMP = 1448
) (
    input  logic [1:0] bits_in,
    output logic signed [OUT_W-1:0] i_sym,
    output logic signed [OUT_W-1:0] q_sym
);

    always_comb begin
        unique case (bits_in)
            2'b00: begin
                i_sym =  AMP;
                q_sym =  AMP;
            end
            2'b01: begin
                i_sym = -AMP;
                q_sym =  AMP;
            end
            2'b11: begin
                i_sym = -AMP;
                q_sym = -AMP;
            end
            2'b10: begin
                i_sym =  AMP;
                q_sym = -AMP;
            end
            default: begin
                i_sym = '0;
                q_sym = '0;
            end
        endcase
    end

endmodule
