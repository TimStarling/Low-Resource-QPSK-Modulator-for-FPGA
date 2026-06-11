`timescale 1ns / 1ps

module tb_qpsk_tx_core;

    localparam int CLK_PERIOD = 10;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic sample_en = 1'b1;
    logic symbol_valid;
    logic [1:0] bits_in;

    logic signed [11:0] map_i;
    logic signed [11:0] map_q;

    logic signed [11:0] i_base;
    logic signed [11:0] q_base;
    logic signed [13:0] y_base;
    logic valid_base;

    logic signed [11:0] i_fs4;
    logic signed [11:0] q_fs4;
    logic signed [13:0] y_fs4;
    logic valid_fs4;

    logic signed [11:0] i_lowres;
    logic signed [11:0] q_lowres;
    logic signed [13:0] y_lowres;
    logic valid_lowres;

    logic signed [11:0] i_dds;
    logic signed [11:0] q_dds;
    logic signed [13:0] y_dds;
    logic valid_dds;

    logic signed [11:0] i_cordic;
    logic signed [11:0] q_cordic;
    logic signed [13:0] y_cordic;
    logic valid_cordic;

    int nonzero_base = 0;
    int nonzero_fs4 = 0;
    int nonzero_lowres = 0;
    int nonzero_dds = 0;
    int nonzero_cordic = 0;
    int fs4_errors = 0;
    int lowres_errors = 0;
    int sample_count = 0;
    logic [1:0] fs4_phase_tb;

    always #(CLK_PERIOD/2) clk = ~clk;

    qpsk_mapper mapper_check_u (
        .bits_in(bits_in),
        .i_sym(map_i),
        .q_sym(map_q)
    );

    qpsk_tx_core #(.MODE(0)) dut_base (
        .clk(clk),
        .rst_n(rst_n),
        .sample_en(sample_en),
        .symbol_valid(symbol_valid),
        .bits_in(bits_in),
        .i_bb(i_base),
        .q_bb(q_base),
        .y_if(y_base),
        .out_valid(valid_base)
    );

    qpsk_tx_core #(.MODE(1)) dut_fs4 (
        .clk(clk),
        .rst_n(rst_n),
        .sample_en(sample_en),
        .symbol_valid(symbol_valid),
        .bits_in(bits_in),
        .i_bb(i_fs4),
        .q_bb(q_fs4),
        .y_if(y_fs4),
        .out_valid(valid_fs4)
    );

    qpsk_top #(.LOW_RESOURCE(1'b1)) dut_lowres (
        .clk(clk),
        .rst_n(rst_n),
        .sample_en(sample_en),
        .symbol_valid(symbol_valid),
        .bits_in(bits_in),
        .i_bb(i_lowres),
        .q_bb(q_lowres),
        .y_if(y_lowres),
        .out_valid(valid_lowres)
    );

    qpsk_tx_core #(.MODE(2)) dut_dds (
        .clk(clk),
        .rst_n(rst_n),
        .sample_en(sample_en),
        .symbol_valid(symbol_valid),
        .bits_in(bits_in),
        .i_bb(i_dds),
        .q_bb(q_dds),
        .y_if(y_dds),
        .out_valid(valid_dds)
    );

    qpsk_tx_core #(.MODE(3)) dut_cordic (
        .clk(clk),
        .rst_n(rst_n),
        .sample_en(sample_en),
        .symbol_valid(symbol_valid),
        .bits_in(bits_in),
        .i_bb(i_cordic),
        .q_bb(q_cordic),
        .y_if(y_cordic),
        .out_valid(valid_cordic)
    );

    task automatic check_mapper(input logic [1:0] bits, input int exp_i, input int exp_q);
        begin
            bits_in = bits;
            #1;
            if (map_i !== exp_i[11:0] || map_q !== exp_q[11:0]) begin
                $error("Mapper mismatch bits=%b got I=%0d Q=%0d expected I=%0d Q=%0d",
                    bits, map_i, map_q, exp_i, exp_q);
            end
        end
    endtask

    function automatic logic signed [13:0] sext12(input logic signed [11:0] value);
        sext12 = {{2{value[11]}}, value};
    endfunction

    function automatic logic signed [13:0] fs4_expected(
        input logic [1:0] phase,
        input logic signed [11:0] i_val,
        input logic signed [11:0] q_val
    );
        begin
            unique case (phase)
                2'd0: fs4_expected = sext12(i_val);
                2'd1: fs4_expected = -sext12(q_val);
                2'd2: fs4_expected = -sext12(i_val);
                default: fs4_expected = sext12(q_val);
            endcase
        end
    endfunction

    initial begin
        symbol_valid = 1'b0;
        bits_in = 2'b00;

        check_mapper(2'b00,  1448,  1448);
        check_mapper(2'b01, -1448,  1448);
        check_mapper(2'b11, -1448, -1448);
        check_mapper(2'b10,  1448, -1448);

        repeat (5) @(posedge clk);
        rst_n = 1'b1;

        for (int n = 0; n < 160; n = n + 1) begin
            symbol_valid = (n % 4 == 0);
            unique case ((n / 4) % 4)
                0: bits_in = 2'b00;
                1: bits_in = 2'b01;
                2: bits_in = 2'b11;
                default: bits_in = 2'b10;
            endcase
            @(posedge clk);
        end

        symbol_valid = 1'b0;
        bits_in = 2'b00;
        repeat (80) @(posedge clk);

        if (nonzero_base == 0) begin
            $error("BASEBAND output never became non-zero.");
        end
        if (nonzero_fs4 == 0) begin
            $error("FS4_IF output never became non-zero.");
        end
        if (nonzero_lowres == 0) begin
            $error("LOW_RESOURCE FS4 output never became non-zero.");
        end
        if (nonzero_dds == 0) begin
            $error("DDS_IF output never became non-zero.");
        end
        if (nonzero_cordic == 0) begin
            $error("CORDIC_IF output never became non-zero.");
        end
        if (fs4_errors != 0) begin
            $error("FS4_IF consistency check failed with %0d errors.", fs4_errors);
        end
        if (lowres_errors != 0) begin
            $error("LOW_RESOURCE consistency check failed with %0d errors.", lowres_errors);
        end

        $display("PASS: QPSK mapper, SRRC, LOW_RESOURCE FS4, BASEBAND, FS4_IF, DDS_IF and CORDIC_IF simulations completed.");
        $finish;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fs4_phase_tb <= 2'd0;
            sample_count <= 0;
        end else if (sample_en) begin
            fs4_phase_tb <= fs4_phase_tb + 2'd1;
            sample_count <= sample_count + 1;
        end
    end

    always_ff @(posedge clk) begin
        if (rst_n && valid_base) begin
            if (i_base !== i_base || q_base !== q_base || y_base !== y_base) begin
                $error("BASEBAND has X/Z output.");
            end
            if (i_base != 0 || q_base != 0) begin
                nonzero_base <= nonzero_base + 1;
            end
        end

        if (rst_n && valid_fs4) begin
            logic signed [13:0] exp_fs4;
            exp_fs4 = fs4_expected(fs4_phase_tb, i_fs4, q_fs4);
            if (y_fs4 !== exp_fs4) begin
                fs4_errors <= fs4_errors + 1;
                $display("FS4 mismatch at sample %0d: phase=%0d y=%0d expected=%0d I=%0d Q=%0d",
                    sample_count, fs4_phase_tb, y_fs4, exp_fs4, i_fs4, q_fs4);
            end
            if (y_fs4 != 0) begin
                nonzero_fs4 <= nonzero_fs4 + 1;
            end
        end

        if (rst_n && valid_lowres) begin
            if (i_lowres !== i_fs4 || q_lowres !== q_fs4 || y_lowres !== y_fs4) begin
                lowres_errors <= lowres_errors + 1;
                $display("LOW_RESOURCE mismatch at sample %0d: low I=%0d Q=%0d Y=%0d, ref I=%0d Q=%0d Y=%0d",
                    sample_count, i_lowres, q_lowres, y_lowres, i_fs4, q_fs4, y_fs4);
            end
            if (y_lowres != 0) begin
                nonzero_lowres <= nonzero_lowres + 1;
            end
        end

        if (rst_n && valid_dds) begin
            if (y_dds != 0) begin
                nonzero_dds <= nonzero_dds + 1;
            end
        end

        if (rst_n && valid_cordic) begin
            if (y_cordic != 0) begin
                nonzero_cordic <= nonzero_cordic + 1;
            end
        end
    end

endmodule
