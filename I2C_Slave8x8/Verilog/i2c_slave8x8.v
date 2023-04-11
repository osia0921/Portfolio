`timescale 1ns / 1ps

module i2c_slave8x8
(
input        sys_clk  ,
input        scl      ,
input        reset_n  ,
inout        sda      ,
output       reg_wen  ,
output       reg_ren  ,
output [7:0] reg_addr ,
output [7:0] reg_wdata,
input  [7:0] reg_rdata
);


parameter SDI_POS = 10'd100; // input_sda를 읽을 위치 scl_posedge 이후에 SDI_POS에 설정된 Clock 후에 데이터를 읽는다. 
parameter i2c_slave8x8_ID = 7'b1010000; // Slave address(ID) (7bits) 

// 1) define state -> 여기서는 sys_clk이 scl보다 한참 빠르므로 c_state, n_state로 나누지 않겠다.
reg [2:0] s_state; // slave_state
parameter IDLE     = 3'd0;
parameter SLAVE_ID = 3'd1;
parameter REG_ADDR = 3'd2;
parameter W_DATA   = 3'd3;
parameter R_DATA   = 3'd4;
// 2) state flag
wire s_idle     = (s_state == IDLE    ) ? 1'b1 : 1'b0 ;
wire s_slave_id = (s_state == SLAVE_ID) ? 1'b1 : 1'b0 ;
wire s_reg_addr = (s_state == REG_ADDR) ? 1'b1 : 1'b0 ;
wire s_w_data   = (s_state == W_DATA  ) ? 1'b1 : 1'b0 ;
wire s_r_data   = (s_state == R_DATA  ) ? 1'b1 : 1'b0 ;

reg scl_1d, scl_2d, scl_3d;
wire scl_posedge =  scl_2d & ~scl_3d; // glitch 방지 위해 2번 delay된 scl와 3번 delay된 scl을 이용
wire scl_negedge = ~scl_2d &  scl_3d; // glitch 방지 위해 2번 delay된 scl와 3번 delay된 scl을 이용

always @ (posedge sys_clk or negedge reset_n) begin // glitch 방지 위해
    if(!reset_n) begin
        scl_1d <= 1'b0;
        scl_2d <= 1'b0;
        scl_3d <= 1'b0;
    end else begin
        scl_1d <= scl;
        scl_2d <= scl_1d;
        scl_3d <= scl_2d;
    end
end

reg sda_1d, sda_2d, sda_3d;
wire sda_posedge =  sda_2d & ~sda_3d;
wire sda_negedge = ~sda_2d &  sda_3d;

always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        sda_1d <= 1'b0;
        sda_2d <= 1'b0;
        sda_3d <= 1'b0;
    end else begin
        sda_1d <= sda;
        sda_2d <= sda_1d;
        sda_3d <= sda_2d;
    end
end

wire i2c_start = scl_2d & sda_negedge;
wire i2c_stop  = scl_2d & sda_posedge;

// 3-1) slave id state -> scl이 high일 때 sda가 데이터이다. ( sda가 low 일 때 데이터가 변하므로 )

reg [3:0] sid_sclN; // counter scl_negedge in slave_id state
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        sid_sclN <= 4'd0;
    end else begin
        sid_sclN <= ~s_slave_id ? 4'd0 : scl_negedge ? sid_sclN + 1 : sid_sclN; // slave_id 일 때 scl_negedge를 카운트한다.-> negedge의 간격은 넓기 때문에 negedge이 특정 값일 때, sid_sclH가 몇일 때 값을 채야한다. 
    end
end

reg [9:0] sid_sclH; // scl이 High일 때 High 동안 카운트를 한다 -> scl이 high 일 때 sda가 데이터이므로 high 중간에 데이터를 챌 것이다. -> scl이 40K, 400K 어느 전송속도에서도 잘 채야한다.
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        sid_sclH <= 10'd0;
    end else begin
        sid_sclH <= (~s_slave_id | ~scl_3d)? 10'd0 : (sid_sclH == 10'd1023) ? 10'd1023 : sid_sclH + 1'b1 ; // slave_id일 때 scl이 HIGH 일 때만 카운트하도록 설계 -> scl = LOW 또는 slave_id 가 아니면 counter 값 초기화 
    end
end

reg [7:0] r_slave_id; // slave_id register
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        r_slave_id <= 8'd0;
    end else begin
        r_slave_id[7] <= (s_slave_id & (sid_sclN == 4'd1) & (sid_sclH == SDI_POS)) ? sda_3d : r_slave_id[7];
        r_slave_id[6] <= (s_slave_id & (sid_sclN == 4'd2) & (sid_sclH == SDI_POS)) ? sda_3d : r_slave_id[6];
        r_slave_id[5] <= (s_slave_id & (sid_sclN == 4'd3) & (sid_sclH == SDI_POS)) ? sda_3d : r_slave_id[5];
        r_slave_id[4] <= (s_slave_id & (sid_sclN == 4'd4) & (sid_sclH == SDI_POS)) ? sda_3d : r_slave_id[4];
        r_slave_id[3] <= (s_slave_id & (sid_sclN == 4'd5) & (sid_sclH == SDI_POS)) ? sda_3d : r_slave_id[3];
        r_slave_id[2] <= (s_slave_id & (sid_sclN == 4'd6) & (sid_sclH == SDI_POS)) ? sda_3d : r_slave_id[2];
        r_slave_id[1] <= (s_slave_id & (sid_sclN == 4'd7) & (sid_sclH == SDI_POS)) ? sda_3d : r_slave_id[1];
        r_slave_id[0] <= (s_slave_id & (sid_sclN == 4'd8) & (sid_sclH == SDI_POS)) ? sda_3d : r_slave_id[0];
    end
end

// 3-2) REG_ADDR state (reg addr state)
reg [3:0] reg_addr_sclN; // counter scl_negedge in reg_addr state
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        reg_addr_sclN <= 4'd0;
    end else begin
        reg_addr_sclN <= ~s_reg_addr ? 4'd0 : scl_negedge ? reg_addr_sclN + 1 : reg_addr_sclN; // reg_addr 일 때 scl_negedge를 카운트한다.-> negedge의 간격은 넓기 때문에 negedge이 특정 값일 때, reg_addr_sclH가 몇일 때 값을 채야한다. 
    end
end

reg [9:0] reg_addr_sclH; // scl이 High일 때 High 동안 카운트를 한다 -> scl이 high 일 때 sda가 데이터이므로 high 중간에 데이터를 챌 것이다. -> scl이 40K, 400K 어느 전송속도에서도 잘 채야한다.
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        reg_addr_sclH <= 10'd0;
    end else begin
        reg_addr_sclH <= (~s_reg_addr | ~scl_3d)? 10'd0 : (reg_addr_sclH == 10'd1023) ? 10'd1023 : reg_addr_sclH + 1'b1 ; // slave_id일 때 scl이 HIGH 일 때만 카운트하도록 설계 -> scl = LOW 또는 slave_id 가 아니면 counter 값 초기화 
    end
end

reg [7:0] register_addr;
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        register_addr <= 8'd0;
    end else begin
        register_addr[7] <= (s_reg_addr & (reg_addr_sclN == 4'd0) & (reg_addr_sclH == SDI_POS)) ? sda_3d : register_addr[7];
        register_addr[6] <= (s_reg_addr & (reg_addr_sclN == 4'd1) & (reg_addr_sclH == SDI_POS)) ? sda_3d : register_addr[6];
        register_addr[5] <= (s_reg_addr & (reg_addr_sclN == 4'd2) & (reg_addr_sclH == SDI_POS)) ? sda_3d : register_addr[5];
        register_addr[4] <= (s_reg_addr & (reg_addr_sclN == 4'd3) & (reg_addr_sclH == SDI_POS)) ? sda_3d : register_addr[4];
        register_addr[3] <= (s_reg_addr & (reg_addr_sclN == 4'd4) & (reg_addr_sclH == SDI_POS)) ? sda_3d : register_addr[3];
        register_addr[2] <= (s_reg_addr & (reg_addr_sclN == 4'd5) & (reg_addr_sclH == SDI_POS)) ? sda_3d : register_addr[2];
        register_addr[1] <= (s_reg_addr & (reg_addr_sclN == 4'd6) & (reg_addr_sclH == SDI_POS)) ? sda_3d : register_addr[1];
        register_addr[0] <= (s_reg_addr & (reg_addr_sclN == 4'd7) & (reg_addr_sclH == SDI_POS)) ? sda_3d : register_addr[0];
    end
end

// 3-3) W_DATA state 
reg [3:0] w_data_sclN; // counter scl_negedge in reg_addr state
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        w_data_sclN <= 4'd0;
    end else begin
        w_data_sclN <= ~s_w_data ? 4'd0 : scl_negedge ? w_data_sclN + 1 : w_data_sclN; // w_data 일 때 scl_negedge를 카운트한다.-> negedge의 간격은 넓기 때문에 negedge이 특정 값일 때, w_data_sclH가 몇일 때 값을 채야한다. 
    end
end

reg [9:0] w_data_sclH; // scl이 High일 때 High 동안 카운트를 한다 -> scl이 high 일 때 sda가 데이터이므로 high 중간에 데이터를 챌 것이다. -> scl이 40K, 400K 어느 전송속도에서도 잘 채야한다.
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        w_data_sclH <= 10'd0;
    end else begin
        w_data_sclH <= (~s_w_data | ~scl_3d)? 10'd0 : (w_data_sclH == 10'd1023) ? 10'd1023 : w_data_sclH + 1'b1 ; // slave_id일 때 scl이 HIGH 일 때만 카운트하도록 설계 -> scl = LOW 또는 slave_id 가 아니면 counter 값 초기화 
    end
end

reg [7:0] register_data;
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        register_data <= 8'd0;
    end else begin
        register_data[7] <= (s_w_data & (w_data_sclN == 4'd0) & (w_data_sclH == SDI_POS)) ? sda_3d : register_data[7];
        register_data[6] <= (s_w_data & (w_data_sclN == 4'd1) & (w_data_sclH == SDI_POS)) ? sda_3d : register_data[6];
        register_data[5] <= (s_w_data & (w_data_sclN == 4'd2) & (w_data_sclH == SDI_POS)) ? sda_3d : register_data[5];
        register_data[4] <= (s_w_data & (w_data_sclN == 4'd3) & (w_data_sclH == SDI_POS)) ? sda_3d : register_data[4];
        register_data[3] <= (s_w_data & (w_data_sclN == 4'd4) & (w_data_sclH == SDI_POS)) ? sda_3d : register_data[3];
        register_data[2] <= (s_w_data & (w_data_sclN == 4'd5) & (w_data_sclH == SDI_POS)) ? sda_3d : register_data[2];
        register_data[1] <= (s_w_data & (w_data_sclN == 4'd6) & (w_data_sclH == SDI_POS)) ? sda_3d : register_data[1];
        register_data[0] <= (s_w_data & (w_data_sclN == 4'd7) & (w_data_sclH == SDI_POS)) ? sda_3d : register_data[0];
    end
end

// 3-4) R_DATA state 
reg [3:0] r_data_sclN; // counter scl_negedge in reg_addr state
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        r_data_sclN <= 4'd0;
    end else begin
        r_data_sclN <= ~s_r_data ? 4'd0 : scl_negedge ? r_data_sclN + 1 : r_data_sclN; // r_data 일 때 scl_negedge를 카운트한다.-> negedge의 간격은 넓기 때문에 negedge이 특정 값일 때, r_data_sclH가 몇일 때 값을 채야한다. 
    end
end

reg [9:0] r_data_sclH; // scl이 High일 때 High 동안 카운트를 한다 -> scl이 high 일 때 sda가 데이터이므로 high 중간에 데이터를 챌 것이다. -> scl이 40K, 400K 어느 전송속도에서도 잘 채야한다.
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        r_data_sclH <= 10'd0;
    end else begin
        r_data_sclH <= (~s_r_data | ~scl_3d)? 10'd0 : (r_data_sclH == 10'd1023) ? 10'd1023 : r_data_sclH + 1'b1 ; // r_data일 때 scl이 HIGH 일 때만 카운트하도록 설계 -> scl = LOW 또는 r_data 가 아니면 counter 값 초기화 
    end
end

// 4) ack
reg ack_pulse; // slave가 master에게 sda를 output하는 시간 
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        ack_pulse <= 1'd0;
    end else begin
        ack_pulse <= (scl_posedge & (sid_sclN      == 4'd9)) ? 1'b1 : (scl_posedge & s_reg_addr & (reg_addr_sclN != 4'd8)) ? 1'b0 :
                     (scl_posedge & (reg_addr_sclN == 4'd8)) ? 1'b1 : (scl_posedge & s_w_data  ) ? 1'b0 :
                     (scl_posedge & (r_data_sclN   == 4'd8)) ? 1'b0 : ack_pulse;
    end
end

 // 5) sda_output
assign sda = ack_pulse ? ((s_r_data & scl_posedge & (r_data_sclN <= 4'd7)) ? reg_rdata[4'd7-r_data_sclN] : (s_r_data) ? sda : 1'b0) : 1'bz; 

// 6) state transition
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        s_state <= 3'd0; // IDLE
    end else begin
        s_state <= (s_idle & i2c_start) ? SLAVE_ID : 
        
                   (s_slave_id & (sid_sclN == 4'd10) & (r_slave_id == {i2c_slave8x8_ID, 1'b0})) ? REG_ADDR  :
                   (s_slave_id & (sid_sclN == 4'd10) & (r_slave_id == {i2c_slave8x8_ID, 1'b1})) ? R_DATA    :
                   (s_slave_id & (sid_sclN == 4'd10) & (r_slave_id[7:1] != i2c_slave8x8_ID)   ) ? IDLE      :
                   
                   (s_reg_addr & (reg_addr_sclN == 4'd9 )             ) ? W_DATA   :
                   (s_w_data   & (w_data_sclN   == 4'd0 ) & i2c_start ) ? SLAVE_ID :
                   (s_w_data   & (w_data_sclN   == 4'd9 )             ) ? IDLE     : 
                   (s_r_data   & (r_data_sclN   == 4'd9 ) & i2c_stop  ) ? IDLE     : s_state; 
                   
    end
end

// 7) register read / write
reg [7:0] reg_wdata;
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        reg_wdata <= 8'b0;
    end else begin
        reg_wdata <= (s_w_data & (w_data_sclN == 4'd8) & (w_data_sclH == 10'd10)) ? register_data : reg_wdata;
    end
end

reg reg_wen;
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        reg_wen <= 1'b0;
    end else begin
        reg_wen <= (s_w_data & (w_data_sclN == 4'd8) & (w_data_sclH == 10'd14)) ? 1'b1 : 1'b0;
    end
end

reg [7:0] reg_addr;
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        reg_addr <= 8'b0;
    end else begin
        reg_addr <= (s_reg_addr & (reg_addr_sclN == 4'd8) & (reg_addr_sclH == 10'd14)) ? register_addr : reg_addr;
    end
end

reg reg_ren;
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        reg_ren <= 1'b0;
    end else begin
        reg_ren <= (s_r_data & (r_data_sclN == 4'd0) & (r_data_sclH == 10'd14)) ? 1'b1 :
                    (s_r_data & (r_data_sclN == 4'd8) & (r_data_sclH == 10'd14)) ? 1'b1 : 1'b0;
    end
end

endmodule
