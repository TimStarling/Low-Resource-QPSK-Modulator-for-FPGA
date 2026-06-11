`timescale 1ns / 1ps

module dds_carrier #(
    parameter int PHASE_W = 18,
    parameter int AMP_W = 12,
    parameter logic [PHASE_W-1:0] PHASE_INC = 18'd65536
) (
    input  logic clk,
    input  logic rst_n,
    input  logic sample_en,
    output logic signed [AMP_W-1:0] cos_o,
    output logic signed [AMP_W-1:0] sin_o
);

    localparam logic signed [AMP_W-1:0] SIN_LUT [0:63] = '{
        12'sd0, 12'sd51, 12'sd102, 12'sd153, 12'sd204, 12'sd255, 12'sd305, 12'sd355,
        12'sd406, 12'sd456, 12'sd505, 12'sd554, 12'sd603, 12'sd652, 12'sd700, 12'sd748,
        12'sd795, 12'sd842, 12'sd888, 12'sd934, 12'sd979, 12'sd1023, 12'sd1067, 12'sd1111,
        12'sd1153, 12'sd1195, 12'sd1236, 12'sd1276, 12'sd1316, 12'sd1354, 12'sd1392, 12'sd1429,
        12'sd1465, 12'sd1501, 12'sd1535, 12'sd1568, 12'sd1600, 12'sd1632, 12'sd1662, 12'sd1691,
        12'sd1720, 12'sd1747, 12'sd1773, 12'sd1798, 12'sd1822, 12'sd1844, 12'sd1866, 12'sd1886,
        12'sd1905, 12'sd1924, 12'sd1940, 12'sd1956, 12'sd1970, 12'sd1984, 12'sd1996, 12'sd2006,
        12'sd2016, 12'sd2024, 12'sd2031, 12'sd2037, 12'sd2041, 12'sd2044, 12'sd2046, 12'sd2047
    };

    logic [PHASE_W-1:0] phase;
    logic [1:0] quadrant;
    logic [5:0] addr;
    logic signed [AMP_W-1:0] sin_abs;
    logic signed [AMP_W-1:0] cos_abs;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= '0;
        end else if (sample_en) begin
            phase <= phase + PHASE_INC;
        end
    end

    always_comb begin
        quadrant = phase[PHASE_W-1 -: 2];
        addr = phase[PHASE_W-3 -: 6];
        sin_abs = SIN_LUT[addr];
        cos_abs = SIN_LUT[6'd63 - addr];
        unique case (quadrant)
            2'd0: begin
                sin_o =  sin_abs;
                cos_o =  cos_abs;
            end
            2'd1: begin
                sin_o =  cos_abs;
                cos_o = -sin_abs;
            end
            2'd2: begin
                sin_o = -sin_abs;
                cos_o = -cos_abs;
            end
            default: begin
                sin_o = -cos_abs;
                cos_o =  sin_abs;
            end
        endcase
    end

endmodule
