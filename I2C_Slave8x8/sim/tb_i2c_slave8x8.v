`timescale 1ns / 1ps
`define SIM_WRITE1
`define SIM_READ1;

module tb_i2c_slave8x8();
reg  sys_clk   ;
reg  scl       ;
reg  reset_n   ;
reg  sda_in    ;
wire sda       ;
wire reg_wen   ;
wire reg_ren   ;
wire [7:0] reg_addr  ; 
wire [7:0] reg_wdata ;
wire [7:0] reg_rdata ;

assign sda = !(i2c_slave8x8.ack_pulse) ? sda_in : 1'bz;
//assign sda = sda_in;

//Clock
always #5 sys_clk = ~sys_clk; // 한 주기 = 10ns -> 100Mhz
always #1250 scl = ~scl;      // 25x10^(-7)=2500x10^(-9)=2500ns -> 400Kbps

initial begin
    sys_clk = 0;
    scl     = 0;
    sda_in  = 1;
    reset_n = 1;
    #625
    reset_n = 0;
    #312.5
    reset_n = 1;
    #937.5
    `ifdef SIM_WRITE1
        sda_in = 0;
        #1250
        // Slave ID (7bits) = 0xA0
        sda_in = 1; #2500 sda_in = 0; #2500 sda_in = 1; #2500 sda_in = 0; #2500 sda_in = 0; #2500 sda_in = 0; #2500 sda_in = 0; #2500
        // R/W
        sda_in = 0; #2500
        // ACK
        sda_in = 0; #2500 // Should be removed after dut design
        
        // Register Address (8bits) = 0xC1
        sda_in = 1; #2500 sda_in = 1; #2500 sda_in = 0; #2500 sda_in = 0; #2500 sda_in = 0; #2500 sda_in = 0; #2500 sda_in = 0; #2500 sda_in = 1; #2500
        // ACK
        sda_in = 0; #2500 // Should be removed after dut design
        
        // Write Data (8bits) = 0x55
        sda_in = 0; #2500 sda_in = 1; #2500 sda_in = 0; #2500 sda_in = 1; #2500 sda_in = 0; #2500 sda_in = 1; #2500 sda_in = 0; #2500 sda_in = 1; #2500
        // ACK
        sda_in = 0; #2500 // Should be removed after dut design
        // STOP
        sda_in = 0; #1250
        // IDLE
        sda_in = 1; #10000
    `endif
    `ifdef SIM_READ1
         sda_in = 0;
        #1250
        // Slave ID (7bits) = 0xA0
        sda_in = 1; #2500 sda_in = 0; #2500 sda_in = 1; #2500 sda_in = 0; #2500 sda_in = 0; #2500 sda_in = 0; #2500 sda_in = 0; #2500
        // R/W
        sda_in = 0; #2500
        // ACK
        sda_in = 0; #2500 // Should be removed after dut design
        
        // Register Address (8bits) = 0xC1
        sda_in = 1; #2500 sda_in = 1; #2500 sda_in = 0; #2500 sda_in = 0; #2500 sda_in = 0; #2500 sda_in = 0; #2500 sda_in = 0; #2500 sda_in = 1; #2500
        // ACK
        sda_in = 0; #2500 // Should be removed after dut design
        
        //Repeated Start
        sda_in = 0; #625 sda_in = 1; #625 sda_in = 0; #1250
        
        // Slave ID (7bits) = 0xA0
        sda_in = 1; #2500 sda_in = 0; #2500 sda_in = 1; #2500 sda_in = 0; #2500 sda_in = 0; #2500 sda_in = 0; #2500 sda_in = 0; #2500
        // R/W ( Read )
        sda_in = 1; #2500 
        // ACK
        sda_in = 0; #2500 // Should be removed after dut design
        
        // Read Data
        sda_in = 0; #20000 // Should be removed after dut design
        
        // NACK
        sda_in = 1; #2500
        // STOP
        sda_in = 0; #1250
        // IDLE
        sda_in = 1; #10000
    `endif
    $finish;
end

// Call DUT
i2c_slave8x8 u_i2c_slave8x8
(
.sys_clk   (sys_clk)    ,
.scl       (scl)        ,
.reset_n   (reset_n)    , 
.sda       (sda)        ,
.reg_wen   (reg_wen)    ,
.reg_ren   (reg_ren)    ,
.reg_addr  (reg_addr)   ,
.reg_wdata (reg_wdata)  ,
.reg_rdata (reg_rdata)
);

i2c_reg8x8 u_i2c_reg8x8
(
.sys_clk  (sys_clk  ),
.reset_n  (reset_n  ),
.reg_wen  (reg_wen  ),
.reg_ren  (reg_ren  ),
.reg_addr (reg_addr ),
.reg_wdata(reg_wdata),
.reg_rdata(reg_rdata)
);
endmodule
