`include "timescale.vh"

module cnn_core(
    clk             ,
    reset_n         ,        
    i_soft_reset    ,
    i_in_fmap       ,
    i_in_weight     ,
    i_in_bias       ,
    i_in_valid      ,
    o_ot_fmap       ,
    o_ot_valid
    );
`include "define_cnn_core.vh"
localparam LATENCY = 1;

input                               clk             ;
input                               reset_n         ;        
input                               i_soft_reset    ;
input    [  CI*KX*KY*I_FM_BW-1 : 0] i_in_fmap       ;
//input    [CO*CI*KX*KY*I_W_BW-1 : 0] i_in_weight   ;
//input             [CO*I_B_BW-1 : 0] i_in_bias     ;
//--ADD
input                [I_W_BW-1 : 0] i_in_weight     ;
input                [I_B_BW-1 : 0] i_in_bias       ;
//---
input                               i_in_valid      ;
output            [CO*O_F_BW-1 : 0] o_ot_fmap       ;
output                              o_ot_valid      ;
//--ADD 
wire   [CO*CI*KX*KY*I_W_BW-1 : 0] w_cnn_weight      ;
wire            [CO*I_B_BW-1 : 0] w_cnn_bias        ;
reg    [CO*CI*KX*KY*I_W_BW-1 : 0] cnn_weight        ;
reg             [CO*I_B_BW-1 : 0] cnn_bias          ;
//---
reg  [LATENCY-1 : 0] r_valid    ;
wire [CO-1 : 0]      w_ot_valid ;

//--ADD
integer i;

// 입력값이 바뀔 때마다 cnn_weight에 넣어주는 건가? 조합회로니까?
always @ (*) begin
    for(i = 0; i < CO*CI*KX*KY; i = i+1) begin
        cnn_weight[i*I_W_BW +: I_W_BW] = i_in_weight;
    end
end 
// 입력값이 바뀔 때마다 cnn_bias에 넣어주는 건가? 조합회로니까?
always @ (*) begin
    for(i = 0; i < CO; i = i+1) begin
        cnn_bias[i*I_B_BW +: I_B_BW] = i_in_bias;
    end
end 
assign w_cnn_weight = cnn_weight;
assign w_cnn_bias = cnn_bias;
//---

// read_valid : 외부 모듈이 봤을 때, 유효한 cnn_core의 출력 신호
always @ (posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        r_valid <= {LATENCY{1'b0}};
    end else if(i_soft_reset) begin
        r_valid <= {LATENCY{1'b0}};
    end else begin
        r_valid[LATENCY-1] <= &w_ot_valid; // 1clock
    end
end

wire [CO-1 : 0]         w_in_valid  ;
wire [CO*ACI_BW-1 : 0]  w_ot_ci_acc ;

// Step 1) cnn_acc_ic를 CO개만큼 instantiation 후 결과값을 모두 불러낸다.
genvar col_idx;
generate
    for (col_idx = 0; col_idx < CO; col_idx = col_idx + 1) begin : gen_col
        assign w_in_valid [col_idx] = i_in_valid;
        wire [CI*KX*KY*I_W_BW-1 : 0] w_cnn_weight_ci =  w_cnn_weight[CI*KX*KY*I_W_BW*col_idx +: CI*KX*KY*I_W_BW]; // ADD(Change)
        (* DONT_TOUCH = "TRUE" *) cnn_acc_ic u_cnn_acc_ic(
            .clk             (clk                                          ),
            .reset_n         (reset_n                                      ),        
            .i_soft_reset    (i_soft_reset                                 ),
            .i_in_fmap       (i_in_fmap                                    ),
            .i_in_weight     (w_cnn_weight_ci                              ), // ADD(Change)
            .i_in_valid      (w_in_valid  [col_idx]                        ),
            .o_ot_ci_acc     (w_ot_ci_acc [ACI_BW*col_idx +: ACI_BW]       ),
            .o_ot_valid      (w_ot_valid  [col_idx]                        )
        );
    end
endgenerate

// Step 2) 불러낸 C0개의 cnn_acc_ic를 각각 bias를 더한다. 
wire [CO*AB_BW-1 : 0] add_bias  ;
reg  [CO*AB_BW-1 : 0] r_add_bias;
genvar add_idx;
generate
    for (add_idx = 0; add_idx < CO; add_idx = add_idx + 1) begin : gen_add_bias
        assign add_bias [AB_BW*add_idx +: AB_BW] = w_ot_ci_acc [ACI_BW*add_idx +: ACI_BW] + w_cnn_bias [I_B_BW*add_idx +: I_B_BW]; // ADD(Change)
        
        always @ (posedge clk or negedge reset_n) begin
            if(!reset_n) begin
                r_add_bias[AB_BW*add_idx +: AB_BW] <= {AB_BW{1'b0}};
            end else if(i_soft_reset) begin
                r_add_bias[AB_BW*add_idx +: AB_BW] <= {AB_BW{1'b0}};
            end else if(&w_ot_valid) begin
                r_add_bias[AB_BW*add_idx +: AB_BW] <= add_bias[AB_BW*add_idx +: AB_BW];
            end
        end
    end
endgenerate

// Step 3) no activation function
assign o_ot_fmap  = r_add_bias;
assign o_ot_valid = r_valid[LATENCY-1];
endmodule
