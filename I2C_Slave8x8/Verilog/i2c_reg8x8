`timescale 1ns / 1ps
`define         rADDR0          8'b11000001


module i2c_reg8x8
(
input         sys_clk  ,
input         reset_n  ,
input         reg_wen  ,
input         reg_ren  ,
input   [7:0] reg_addr ,
input   [7:0] reg_wdata,
output  [7:0] reg_rdata
);

//register map
reg [7:0] reg_10; // reg_10은 reg_addr이 11000001이면 자동하는 register이다. 
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        reg_10 <= 8'haa;
    end else begin
        reg_10 <= (reg_wen & (reg_addr==`rADDR0)) ? reg_wdata : reg_10;
    end
end


reg [7:0] reg_rdata;
always @ (posedge sys_clk or negedge reset_n) begin
    if(!reset_n) begin
        reg_rdata <= 8'b0;
    end else begin
        reg_rdata <= (reg_ren & (reg_addr == `rADDR0)) ? reg_10 : reg_rdata;
    end
end
endmodule
