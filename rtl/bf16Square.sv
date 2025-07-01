module bf16_square (
    input logic [15:0] bf16_in,  // 输入BF16: [15:符号, 14:7指数, 6:0尾数]
    output logic [31:0] fp32_out  // 输出FP32
);

    // 提取字段
    logic sign;
    logic [7:0] exponent;
    logic [6:0] mantissa;
    
    assign sign = bf16_in[15];
    assign exponent = bf16_in[14:7];
    assign mantissa = bf16_in[6:0];
    
    // LUT (128x24位)
    logic [23:0] lut [0:127];
    initial begin
        $readmemh("bf16_square_lut.mem", lut);
    end
    
    // LUT输出
    logic [23:0] lut_out;
    assign lut_out = lut[mantissa];
    
    // 分离LUT输出
    logic exp_increment;      // 指数增量标志
    logic [22:0] sq_mantissa; // 平方后的尾数
    
    assign exp_increment = lut_out[23];
    assign sq_mantissa = lut_out[22:0];
    
    // 指数计算
    logic [8:0] exp_base;    // 9位中间指数 (处理溢出)
    logic [7:0] new_exponent;
    logic exponent_overflow;
    
    // 计算: (exp - 127)*2 + 127 + exp_increment = 2*exp - 127 + exp_increment
    assign exp_base = {1'b0, exponent} * 2;  // 乘以2
    assign new_exponent = exp_base[7:0] - 8'd127 + {7'b0, exp_increment};
    assign exponent_overflow = exp_base[8];   // 检测上溢
    
    // 结果组合 - 纯组合逻辑
    always_comb begin
        // 符号位总是0 (平方结果非负)
        fp32_out[31] = 1'b0;
        
        // 特殊情况处理
        if (exponent == 8'd0) begin
            // 零或次正规数 -> 返回零
            fp32_out[30:0] = 31'b0;
        end
        else if (exponent == 8'hFF) begin
            // 无穷大或NaN -> 保持特殊值
            fp32_out[30:23] = 8'hFF;        // 指数全1
            fp32_out[22:0] = {mantissa, 16'b0}; // 尾数扩展
        end
        else if (exponent_overflow || new_exponent >= 8'hFF) begin
            // 指数上溢 -> 返回无穷大
            fp32_out[30:23] = 8'hFF;
            fp32_out[22:0] = 23'b0;
        end
        else begin
            // 正常情况
            fp32_out[30:23] = new_exponent;
            fp32_out[22:0] = sq_mantissa;
        end
    end

endmodule