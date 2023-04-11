`include "timescale.vh"

module cnn_kernel
(
    clk             ,
    reset_n         ,        
    i_soft_reset    ,
    i_in_fmap       ,
    i_in_weight     ,
    i_in_valid      ,
    o_ot_kernel_acc ,
    o_ot_valid
);
`include "define_cnn_core.vh"
localparam LATENCY = 2;

input                               clk             ;
input                               reset_n         ;        
input                               i_soft_reset    ;
input    [KX*KY*I_FM_BW-1 : 0]      i_in_fmap       ;
input    [KX*KY*I_W_BW-1 : 0]       i_in_weight     ;
input                               i_in_valid      ;
output   [AC_K_BW-1 : 0]            o_ot_kernel_acc ;
output                              o_ot_valid      ;
    
reg  [LATENCY-1:0] r_valid;
wire [LATENCY-1:0] ce;

// read_valid : 외부 모듈이 봤을 때, 유효한 cnn_kernel의 출력값 
always @ (posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        r_valid <= {LATENCY{1'b0}};
    end else if(i_soft_reset) begin
        r_valid <= {LATENCY{1'b0}};
    end else begin
        r_valid[LATENCY-2] <= i_in_valid        ; // 1clock
        r_valid[LATENCY-1] <= r_valid[LATENCY-2]; // 2clock
    end
end

assign ce = r_valid;
// Step 1) multiply i_in_famp & i_in_weight -> 1 Clock 소모

wire [KX*KY*M_BW-1 : 0] mul_kernel;
reg  [KX*KY*M_BW-1 : 0] r_mul_kernel;

genvar mul_idx;
generate
    for(mul_idx = 0; mul_idx < KX*KY; mul_idx = mul_idx + 1) begin : gen_mul
        assign mul_kernel[M_BW*mul_idx +: M_BW] = i_in_fmap[I_FM_BW*mul_idx +: I_FM_BW] * i_in_weight[I_W_BW*mul_idx +: I_W_BW];
        
        always @ (posedge clk or negedge reset_n) begin
            if(!reset_n) begin
                r_mul_kernel[M_BW*mul_idx +: M_BW] <= {M_BW{1'b0}};
            end else if(i_soft_reset) begin
                r_mul_kernel[M_BW*mul_idx +: M_BW] <= {M_BW{1'b0}};
            end else if(i_in_valid)begin
                r_mul_kernel[M_BW*mul_idx +: M_BW] <= mul_kernel[M_BW*mul_idx +: M_BW];
            end
        end
    end
endgenerate

// Step 2) accumulate all multiplied kernels -> 1 Clcok 소모
reg [AC_K_BW-1 : 0] acc_kernel;
reg [AC_K_BW-1 : 0] r_acc_kernel;
integer acc_idx;
generate
    always @ (*) begin
        acc_kernel [0 +: AC_K_BW] = {AC_K_BW{1'b0}};
        for(acc_idx = 0; acc_idx < KX*KY; acc_idx = acc_idx + 1) begin
            acc_kernel[0 +: AC_K_BW] = acc_kernel[0 +: AC_K_BW] + r_mul_kernel[M_BW*acc_idx +: M_BW];
        end
    end
    always @ (posedge clk or negedge reset_n) begin
        if(!reset_n) begin
            r_acc_kernel [0 +: AC_K_BW] <= {AC_K_BW{1'b0}};
        end else if(i_soft_reset) begin
            r_acc_kernel [0 +: AC_K_BW] <= {AC_K_BW{1'b0}};
        end else if (ce[LATENCY-2]) begin // 앞에서 1clock delay됨
            r_acc_kernel [0 +: AC_K_BW] <= acc_kernel[0 +: AC_K_BW];
        end
    end
endgenerate

assign o_ot_valid = r_valid[LATENCY-1];
assign o_ot_kernel_acc = r_acc_kernel;

endmodule
