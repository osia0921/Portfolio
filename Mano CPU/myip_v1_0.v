
`timescale 1 ns / 1 ps


	module myip_v1_0 #
	(
		parameter integer MEM0_DATA_WIDTH = 32,
		parameter integer MEM0_ADDR_WIDTH = 12,     // 9 -> 12
		parameter integer MEM0_MEM_DEPTH  = 4096,   // 512 -> 4096


		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 4 
	)
	(
		// BRAM 0에 대한 memory interface 
		output		[MEM0_ADDR_WIDTH-1:0] 	mem0_addr1,
		output		 						mem0_ce1,
		output		 						mem0_we1,
		input 		[MEM0_DATA_WIDTH-1:0]  	mem0_q1,
		output		[MEM0_DATA_WIDTH-1:0] 	mem0_d1,

        // Mano CPU Port for BUS Characteristic
		input  wire		[MEM0_ADDR_WIDTH-1:0] 	mem0_addr2 ,		//wire [`ADDR_WIDTH-1:0] 	addr0_b0;
	    input  wire		 						mem0_we2   ,		//wire  					we0_b0;
	    output wire 	[MEM0_DATA_WIDTH-1:0]  	mem0_q2    ,		//wire [`DATA_WIDTH-1:0]    q0_b0;
	    input  wire		[MEM0_DATA_WIDTH-1:0] 	mem0_d2	   ,        //wire [`DATA_WIDTH-1:0] 	d0_b0;
	
	    // Memory I/F  (Use BRAM 0 Port 2)
	    output wire [MEM0_ADDR_WIDTH-1:0]  mem0_addr2_1     ,
        output wire                        mem0_we2_1       ,
        input  wire [MEM0_DATA_WIDTH-1:0]  mem0_q2_1        ,
        output wire [MEM0_DATA_WIDTH-1:0]  mem0_d2_1        ,
        
        

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
		input wire  s00_axi_rready,
		
		output wire mano_cpu_reset_n
	);

// Instantiation of Axi Bus Interface S00_AXI
	myip_v1_0_S00_AXI # ( 
		.MEM0_DATA_WIDTH	(MEM0_DATA_WIDTH	),
		.MEM0_ADDR_WIDTH	(MEM0_ADDR_WIDTH	),
		.MEM0_MEM_DEPTH 	(MEM0_MEM_DEPTH 	),

		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) myip_v1_0_S00_AXI_inst (
		// BRAM 0 Port 1
		.mem0_addr1 	(mem0_addr1   ), 	
		.mem0_ce1	  	(mem0_ce1	  ),	
		.mem0_we1	  	(mem0_we1	  ),	
		.mem0_q1	  	(mem0_q1	  ),	
		.mem0_d1	  	(mem0_d1	  ),

        // Mano CPU Port for BUS Characteristic
        .mem0_addr2     (mem0_addr2   ),		
	//    .mem0_ce2,		
		.mem0_we2       (mem0_we2     ),
		.mem0_q2        (mem0_q2      ),
		.mem0_d2        (mem0_d2      ),
		
		// Memory I/F  (Use BRAM 0 Port 2)
	    .mem0_addr2_1   (mem0_addr2_1   ),
        .mem0_we2_1     (mem0_we2_1     ),
        .mem0_q2_1      (mem0_q2_1      ),
        .mem0_d2_1      (mem0_d2_1      ),  

        // AXI4-Lite I/F
		.S_AXI_ACLK     (s00_axi_aclk   ),
		.S_AXI_ARESETN  (s00_axi_aresetn),
		.S_AXI_AWADDR   (s00_axi_awaddr ),
		.S_AXI_AWPROT   (s00_axi_awprot ),
		.S_AXI_AWVALID  (s00_axi_awvalid),
		.S_AXI_AWREADY  (s00_axi_awready),
		.S_AXI_WDATA    (s00_axi_wdata  ),
		.S_AXI_WSTRB    (s00_axi_wstrb  ),
		.S_AXI_WVALID   (s00_axi_wvalid ),
		.S_AXI_WREADY   (s00_axi_wready ),
		.S_AXI_BRESP    (s00_axi_bresp  ),
		.S_AXI_BVALID   (s00_axi_bvalid ),
		.S_AXI_BREADY   (s00_axi_bready ),
		.S_AXI_ARADDR   (s00_axi_araddr ),
		.S_AXI_ARPROT   (s00_axi_arprot ),
		.S_AXI_ARVALID  (s00_axi_arvalid),
		.S_AXI_ARREADY  (s00_axi_arready),
		.S_AXI_RDATA    (s00_axi_rdata  ),
		.S_AXI_RRESP    (s00_axi_rresp  ),
		.S_AXI_RVALID   (s00_axi_rvalid ),
		.S_AXI_RREADY   (s00_axi_rready ),
		.mano_cpu_reset_n(mano_cpu_reset_n)
	);

	endmodule
