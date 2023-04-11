module mano_cpu_wrapper #
(
	parameter integer MEM0_DATA_WIDTH = 32,
	parameter integer MEM0_ADDR_WIDTH = 12,
	parameter integer MEM0_MEM_DEPTH  = 4096,

	// Parameters of Axi Slave Bus Interface S00_AXI
	parameter integer C_S00_AXI_DATA_WIDTH	= 32,
	parameter integer C_S00_AXI_ADDR_WIDTH	= 4
)
(
	// Users to add ports here

	// User ports ends
	// Do not modify the ports beyond this line


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
// BRAM 0 Memory I/F

	// BRAM 0 Port 1
	wire		[MEM0_ADDR_WIDTH-1:0] 	mem0_addr1	;
	wire		 						mem0_ce1	;
	wire		 						mem0_we1	;
	wire 		[MEM0_DATA_WIDTH-1:0]  	mem0_q1		;
	wire		[MEM0_DATA_WIDTH-1:0] 	mem0_d1		;


	// Mano CPU Port for BUS Characteristic
    wire	   [MEM0_ADDR_WIDTH-1:0] 	mem0_addr2 ;		//wire [`ADDR_WIDTH-1:0] 	addr0_b0;
    wire		 						mem0_we2   ;		//wire  					we0_b0;
    wire 	   [MEM0_DATA_WIDTH-1:0]  	mem0_q2    ;		//wire [`DATA_WIDTH-1:0]    q0_b0;
    wire	   [MEM0_DATA_WIDTH-1:0] 	mem0_d2	   ;        //wire [`DATA_WIDTH-1:0] 	d0_b0;
	
    // Memory I/F  (Use BRAM 0 Port 2)
    wire [MEM0_ADDR_WIDTH-1:0] mem0_addr2_1     ;
    wire                       mem0_we2_1       ;
    wire [MEM0_DATA_WIDTH-1:0] mem0_q2_1        ;
    wire [MEM0_DATA_WIDTH-1:0] mem0_d2_1        ;
    
    wire                       mano_cpu_reset_n ;


// Instantiation of Axi Bus Interface S00_AXI
	myip_v1_0 # ( 
		.MEM0_DATA_WIDTH (MEM0_DATA_WIDTH),
		.MEM0_ADDR_WIDTH (MEM0_ADDR_WIDTH),
		.MEM0_MEM_DEPTH  (MEM0_MEM_DEPTH ),
		.C_S00_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S00_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) myip_v1_0_inst (
	//  BRAM 0 Port 1 // USE AXI4LITE 

		.mem0_addr1			(mem0_addr1	),
		.mem0_ce1			(mem0_ce1	),
		.mem0_we1			(mem0_we1	),
		.mem0_q1			(mem0_q1	),
		.mem0_d1			(mem0_d1	),

	     // Mano CPU Port for BUS Characteristic
		.mem0_addr2			(mem0_addr2	),
		.mem0_we2			(mem0_we2	),
		.mem0_q2			(mem0_q2	),
		.mem0_d2			(mem0_d2	),
		
		// Memory I/F  (Use BRAM 0 Port 2)
		.mem0_addr2_1   (mem0_addr2_1   ),
        .mem0_we2_1     (mem0_we2_1     ),
        .mem0_q2_1      (mem0_q2_1      ),
        .mem0_d2_1      (mem0_d2_1      ),  

		.s00_axi_aclk	(s00_axi_aclk	),
		.s00_axi_aresetn(s00_axi_aresetn),
		.s00_axi_awaddr	(s00_axi_awaddr	),
		.s00_axi_awprot	(s00_axi_awprot	),
		.s00_axi_awvalid(s00_axi_awvalid),
		.s00_axi_awready(s00_axi_awready),
		.s00_axi_wdata	(s00_axi_wdata	),
		.s00_axi_wstrb	(s00_axi_wstrb	),
		.s00_axi_wvalid	(s00_axi_wvalid	),
		.s00_axi_wready	(s00_axi_wready	),
		.s00_axi_bresp	(s00_axi_bresp	),
		.s00_axi_bvalid	(s00_axi_bvalid	),
		.s00_axi_bready	(s00_axi_bready	),
		.s00_axi_araddr	(s00_axi_araddr	),
		.s00_axi_arprot	(s00_axi_arprot	),
		.s00_axi_arvalid(s00_axi_arvalid),
		.s00_axi_arready(s00_axi_arready),
		.s00_axi_rdata	(s00_axi_rdata	),
		.s00_axi_rresp	(s00_axi_rresp	),
		.s00_axi_rvalid	(s00_axi_rvalid	),
		.s00_axi_rready	(s00_axi_rready	),
		
		.mano_cpu_reset_n(mano_cpu_reset_n)
	);

	true_dpbram 
	#(	.DWIDTH   (MEM0_DATA_WIDTH), 
		.AWIDTH   (MEM0_ADDR_WIDTH), 
		.MEM_SIZE (MEM0_MEM_DEPTH)) 
	u_TDPBRAM_0(
		.clk		(s00_axi_aclk	), 
	
	// USE AXI4LITE 
		.addr0		(mem0_addr1		), 
		.ce0		(mem0_ce1		), 
		.we0		(mem0_we1		), 
		.q0			(mem0_q1		), 
		.d0			(mem0_d1		), 
	
	// USE Mano CPU
		.addr1 		(mem0_addr2_1 	), 
		.ce1		(1'b1			), 
		.we1		(mem0_we2_1		),
		.q1			(mem0_q2_1		), 
		.d1			(mem0_d2_1		)
	);

	mano_cpu 
	#(	.DWIDTH   (MEM0_DATA_WIDTH), 
		.AWIDTH   (MEM0_ADDR_WIDTH), 
		.MEM_SIZE (MEM0_MEM_DEPTH)
    )
	u_mano_cpu (
    	.clk            (s00_axi_aclk      ),
    	.reset_n        (mano_cpu_reset_n   ),
    	/////////   Memory I/F   (BRAM 0) ////////
    	.dout           (mem0_q2           ), 
    	.din            (mem0_d2           ), 
    	.we             (mem0_we2          ),
    	.ar             (mem0_addr2        )

    	//.ac           (ac         ),  
		//.ce_b0	    (ce0_b0		),
    );

endmodule
