`include "timescale.vh"

module cnn_acc_ic(
    clk             ,
    reset_n         ,        
    i_soft_reset    ,
    i_in_fmap       ,
    i_in_weight     ,
    i_in_valid      ,
    o_ot_ci_acc     ,
    o_ot_valid
    );
`include "define_cnn_core.vh"
localparam LATENCY = 1;

input                               clk             ;
input                               reset_n         ;        
input                               i_soft_reset    ;
input    [CI*KX*KY*I_FM_BW-1 : 0]   i_in_fmap       ;
input    [CI*KX*KY*I_W_BW-1 : 0]    i_in_weight     ;
input                               i_in_valid      ;
output   [ACI_BW-1 : 0]             o_ot_ci_acc     ;
output                              o_ot_valid      ;
    
reg  [LATENCY-1 : 0] r_valid    ;
wire [CI-1 : 0]      w_ot_valid ;

// read_valid : 외부 모듈이 봤을 때, 유효한 cnn_kernel의 출력값 
always @ (posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        r_valid <= {LATENCY{1'b0}};
    end else if(i_soft_reset) begin
        r_valid <= {LATENCY{1'b0}};
    end else begin
        r_valid[LATENCY-1] <= &w_ot_valid; // 1clock
    end
end

wire [CI-1 : 0]         w_in_valid;
wire [CI*AC_K_BW-1 : 0] w_ot_kernel_acc;
// Step 1) cnn_kernel을 CI개만큼 instantiation 후 결과값을 모두 불러낸다.
genvar col_idx;
generate
    for (col_idx = 0; col_idx < CI; col_idx = col_idx + 1) begin : gen_col
        assign w_in_valid [col_idx] = i_in_valid;
        wire [KX*KY*I_FM_BW-1 : 0] w_in_fmap   =  i_in_fmap  [KX*KY*I_FM_BW*col_idx +: KX*KY*I_FM_BW];
        wire [KX*KY*I_W_BW-1  : 0] w_in_weight =  i_in_weight[KX*KY*I_W_BW*col_idx +: KX*KY*I_W_BW];
        cnn_kernel u_cnn_kernel(
            .clk             (clk                                           ),
            .reset_n         (reset_n                                       ),
            .i_soft_reset    (i_soft_reset                                  ),
            .i_in_fmap       (w_in_fmap                                     ),
            .i_in_weight     (w_in_weight                                   ),
            .i_in_valid      (w_in_valid [col_idx]                          ),
            .o_ot_kernel_acc (w_ot_kernel_acc [AC_K_BW*col_idx +: AC_K_BW]  ),
            .o_ot_valid      (w_ot_valid [col_idx]                          )
        );
    end
endgenerate

reg [ACI_BW-1 : 0] ot_ci_acc;
integer acc_idx;
always @ (*) begin
    ot_ci_acc [0 +: ACI_BW] = {ACI_BW{1'b0}};
    for (acc_idx = 0; acc_idx < CI; acc_idx = acc_idx + 1) begin
        ot_ci_acc [0 +: ACI_BW] = ot_ci_acc [0 +: ACI_BW] + w_ot_kernel_acc [AC_K_BW*acc_idx +: AC_K_BW];
    end
end

wire [ACI_BW-1 : 0] w_ot_ci_acc;
assign w_ot_ci_acc = ot_ci_acc;

reg [ACI_BW-1 : 0] r_ot_ci_acc;
always @ (posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        r_ot_ci_acc [0 +: ACI_BW] <= {ACI_BW{1'b0}};
    end else if(i_soft_reset) begin
        r_ot_ci_acc [0 +: ACI_BW] <= {ACI_BW{1'b0}};
    end else if (&w_ot_valid) begin
        r_ot_ci_acc [0 +: ACI_BW] <= w_ot_ci_acc [0 +: ACI_BW];
    end
end

assign o_ot_valid = r_valid[LATENCY-1]; // cnn_kernel의 유효한 출력값이 나오기 시작한 후 1clock 뒤
assign o_ot_ci_acc = r_ot_ci_acc;

endmodule
