`timescale 1 ns / 1 ps
module true_dpbram (
	clk, 
	addr0, 
	ce0, 
	we0, 
	q0, 
	d0, 
	addr1, 
	ce1, 
	we1,
	q1, 
	d1
);

parameter DWIDTH = 32; //parameter DWIDTH = 16; (data_mover_bram)
parameter AWIDTH = 12;
parameter MEM_SIZE = 4096;

input clk;

input[AWIDTH-1:0] addr0;
input ce0;
input we0;
output reg[DWIDTH-1:0] q0; // yunho -> q0 = dout0
input[DWIDTH-1:0] d0;	   // yunho -> d0 = din0

input[AWIDTH-1:0] addr1;
input ce1;
input we1;
output reg[DWIDTH-1:0] q1; // yunho -> q1 = dout0
input[DWIDTH-1:0] d1;	   // yunho -> d1 = din1

(* ram_style = "block" *)reg [DWIDTH-1:0] ram[0:MEM_SIZE-1];

always @(posedge clk)  
begin 
    if (ce0) begin
        if (we0) 
            ram[addr0] <= d0; // yunho -> write (d0 = din0 => 메모리에 Write하고 싶은 값을 쓰면 됨)
		else
        	q0 <= ram[addr0]; // yunho -> read ( q0 = dout0 => Read했을 때 그 값이 출력되는 Data Port)
    end
end

always @(posedge clk)  
begin 
    if (ce1) begin
        if (we1) 
            ram[addr1] <= d1;
		else
        	q1 <= ram[addr1];
    end
end

endmodule
