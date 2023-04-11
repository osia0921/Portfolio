
`timescale 1 ns / 1 ps

	module cnn_core_v1_0 #
	(
		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 6
	)
	(
		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready
	);
	
	`include "define_cnn_core.vh"
	wire                              	w_in_valid  	;
	wire    [CI*KX*KY*I_FM_BW-1 : 0]  	w_in_fmap    	;
	wire                              	w_ot_valid  	;
	wire    [CO*O_F_BW-1 : 0]  			w_ot_fmap    	;

	wire    [I_W_BW-1 : 0]  				w_w_value 		;
	wire    [I_B_BW-1 : 0]  				w_b_value   	;

	reg    [CI*KX*KY*I_FM_BW-1 : 0]  	in_fmap    	;

	wire 					w_data_en;
	wire [I_FM_BW-1 :0] 		w_f_value;
	wire 					w_result_en;
    wire [O_F_BW-1:0] 		w_result_0;
    wire [O_F_ACC_BW-1:0] 	w_result_acc;
// Instantiation of Axi Bus Interface S00_AXI
	axi4_lite_test # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) u_axi4_lite_test (
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready),

		// User ports
		.o_data_en		(w_data_en	 ),
		.o_f_value		(w_f_value	 ),
		.o_w_value		(w_w_value	 ),
		.o_b_value		(w_b_value	 ),
		.i_result_en	(w_result_en ),
    	.i_result_0		(w_result_0	 ),
    	.i_result_acc	(w_result_acc)
	);

	// Add user logic here
	wire clk 	 = s00_axi_aclk;
	wire reset_n = s00_axi_aresetn;

	integer i;
	always @(*) begin
		for(i = 0; i < CI*KX*KY ; i = i+1) begin
			in_fmap[i*I_FM_BW +: I_FM_BW] = w_f_value;
		end
	end
	// Accum result for test
	reg    [O_F_ACC_BW-1 : 0]  		acc_result;
	always @(*) begin
		acc_result = {O_F_ACC_BW{1'b0}};
		for(i = 0; i < CO; i = i+1) begin
			acc_result = acc_result + w_ot_fmap[i*O_F_BW +: O_F_BW] ;
		end
	end
	
	reg    [O_F_ACC_BW-1 : 0]  		r_acc_result;
	reg								r_ot_valid;
	always @(posedge clk or negedge reset_n) begin
	    if(!reset_n) begin
			r_ot_valid	 <= 1'b0;
			r_acc_result <= {O_F_ACC_BW{1'b0}};
	    end else begin
			r_ot_valid	 <= w_ot_valid;
			r_acc_result <= acc_result;
	    end
	end

	assign w_in_valid	= w_data_en;
	assign w_in_fmap 	= in_fmap;

	assign w_result_en	= w_ot_valid && r_ot_valid ;
	assign w_result_0 	= w_ot_fmap[0+:O_F_BW];
	assign w_result_acc = r_acc_result;
	cnn_core u_cnn_core(
    	.clk             (clk    	  ),
    	.reset_n         (reset_n	  ),
    	.i_soft_reset    (1'b0		  ), // no use
    	.i_in_weight     (w_w_value	  ),
    	.i_in_bias       (w_b_value   ),
    	.i_in_valid      (w_in_valid  ),
    	.i_in_fmap       (w_in_fmap   ),
    	.o_ot_valid      (w_ot_valid  ),
    	.o_ot_fmap       (w_ot_fmap   )      
    );

	// User logic ends

	endmodule
