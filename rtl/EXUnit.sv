module EXUnit (
    input  logic              clk,
    input  logic              rst,
    input  logic              enable,
    input  logic              data_en_i,
    input  logic [15:0]       data_i,
    output logic              data_en_o,
    output logic [31:0]       data_o
);

    // bf16->fp32转换函数
    function automatic [31:0] bf16_to_fp32(input logic [15:0] bf16_in);
        bf16_to_fp32 = {bf16_in[15:0], 16'b0};
    endfunction

    // 输入寄存器
    logic [31:0] data_a_reg;
    logic [31:0] data_b_reg;
    logic [2:0]  rnd_mode_reg;
    logic        data_en_reg;

    // DW_fp_add输出
    logic [31:0] z_inst;
    logic [7:0]  status_inst;

    // 结果有效标志
    logic result_valid;

    // 默认舍入模式
    localparam [2:0] RND_MODE = 3'b000;

    // 使能信号记录,打一拍做状态判断
    logic data_en_i_r;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            data_en_i_r<='0;
        end else if (enable) begin
            data_en_i_r<=data_en_i;
        end
    end


    // 计算控制逻辑
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            data_a_reg   <= '0;
            data_b_reg   <= '0;
            rnd_mode_reg <= RND_MODE;
        end else if (enable) begin
            rnd_mode_reg <= RND_MODE;
            case ({data_en_i_r,data_en_i})
                2'b01:begin
                    //接收第一个输入
                    data_a_reg   <= bf16_to_fp32(data_i);
                    data_b_reg   <= '0; // 清空z_inst
                end
                2'b11:begin
                    data_a_reg   <= bf16_to_fp32(data_i);
                    data_b_reg   <= z_inst; // 累加上一次结果
                end
                default: ;
            endcase
        end 
    end

    // DW_fp_add直接参数化例化
    DW_fp_add #(
        23, // sig_width (FP32)
        8,  // exp_width
        0   // ieee_compliance
    ) U1 (
        .a     (data_a_reg),
        .b     (data_b_reg),
        .rnd   (rnd_mode_reg),
        .z     (z_inst),
        .status(status_inst)
    );

    //输出控制逻辑
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            data_en_o<='0;
            data_o<='0;
        end else if (enable) begin
            rnd_mode_reg <= RND_MODE;
            case ({data_en_i_r,data_en_i})
                2'b10:begin
                    data_en_o<='1;
                    data_o<=z_inst;
                end
                default: begin
                    data_en_o<='0;
                end
            endcase
        end 
    end

endmodule
