`timescale 1 ns / 1 ps

	module myip_v1_0_S00_AXI #
	(
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		// 레지스터의 크기가 32bit임을 파라미터로 설정
		parameter integer C_S_AXI_ADDR_WIDTH	= 4,
		// 레지스터의 주소가 4씩 증가함을 파라미터로 설정
		
		// 메모리 parameter 
		parameter integer MEM0_DATA_WIDTH = 32, // 하나의 address에 32bit 데이터
		parameter integer MEM0_ADDR_WIDTH = 12, // 9 -> 12
		parameter integer MEM0_MEM_DEPTH  = 4096 // 2^9 -> 2^12
	)
	(
		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal.
		input wire  S_AXI_ARESETN, // This Signal is Active LOW

		//Write Address Channel (AW)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		input wire [2 : 0] S_AXI_AWPROT,
		input wire  S_AXI_AWVALID,
		output wire  S_AXI_AWREADY,

		//Write Data Channel (W)
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] 		S_AXI_WDATA,  
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] 	S_AXI_WSTRB,
		input wire  S_AXI_WVALID,
		output wire  S_AXI_WREADY,

		//Write Response Channel (B)
		output wire [1 : 0] S_AXI_BRESP,
		output wire  S_AXI_BVALID,
		input wire  S_AXI_BREADY,

		//Read Address Channel (AR)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		input wire [2 : 0] S_AXI_ARPROT,
		input wire  S_AXI_ARVALID,
		output wire  S_AXI_ARREADY,

		//Read Data Channel (R)
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
		output wire [1 : 0] S_AXI_RRESP,
		output wire  S_AXI_RVALID,
		input wire  S_AXI_RREADY,

		// BRAM0에 대한 memory interface (Use BRAM 0 Port 1)
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
        output wire                       mem0_we2_1       ,
        input  wire [MEM0_DATA_WIDTH-1:0] mem0_q2_1        ,
        output wire [MEM0_DATA_WIDTH-1:0] mem0_d2_1        ,

		output wire                       mano_cpu_reset_n 
	);
	
	
	// Mano_CPU, BRAM 0 Port 2 -> for BUS Characteristic
	assign mem0_addr2_1   = mem0_addr2  ;
    assign mem0_we2_1     = mem0_we2    ;
    assign mem0_q2        = mem0_q2_1   ;
    assign mem0_d2_1      = mem0_d2     ;

	// AXI4LITE signals // register를 아래와 같이 선언해놓았고, 
	//register는 어떻게 사용이 되나면, signals 들을 캡쳐 또는 래칭할 때 사용한다.
	//코드로 Slave에서 나와야하는 신호들

	reg  							axi_awready;
	reg  							axi_wready;
	reg  					[1 : 0]	axi_bresp;
	reg  							axi_bvalid;
	reg  							axi_arready;
	reg  [C_S_AXI_DATA_WIDTH-1 : 0] axi_rdata;
	reg 					[1 : 0] axi_rresp;
	reg  							axi_rvalid;

	// BRAM 0에서 data를 read할 때 1cycle delay 됨을 나타내주기 위함. 
	reg 							axi_rvalid_d;

	//Master에서 나오는 신호이며, 주소를 의미함
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;


	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1; 
	// 2인 이유: 하위 2비트를 제거한다는 의미이다. (나중에 코드로 나옴)
	// register의 address가 4씩 증가하므로 0x000, 0x100, 0x200, 0x300 ... 으로 가겠지
	localparam integer OPT_MEM_ADDR_BITS = 1; // 이 신호는 나도 모르겠음.


	//-- Number of Slave Registers 4 
	// 이 레지스터에 우리가 axi4-interface를 통해서 값을 쓰고 읽고 하는 것이다. 
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg0; 
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg3;


	wire	 slv_reg_rden; // 밑에 코드에서 역할을 알게 될 것임.
	wire	 slv_reg_wren; // 밑에 코드에서 역할을 알게 될 것임.

	reg [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;
	// 레지스터에서 나오는(읽힌) 데이터

	integer	 byte_index;
	reg	 aw_en; // 한클락을 주기 위해 필요한 신호?로 보임 


	//코드로 Slave에서 나와야하는 신호들을 Output 신호와 연결시켜줌
	assign S_AXI_AWREADY	= axi_awready;  //reg         axi_awready;
	assign S_AXI_WREADY		= axi_wready;	//reg         axi_wready;
	assign S_AXI_BRESP		= axi_bresp;	//reg [1:0]   axi_bresp;
	assign S_AXI_BVALID		= axi_bvalid;	//reg         axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;	//reg         axi_arready;
	assign S_AXI_RDATA		= axi_rdata;	//reg         axi_rdata;
	assign S_AXI_RRESP		= axi_rresp;	//reg         axi_rresp;

	// BRAM 0에서 data를 read할 때 1cycle delay 됨을 나타내주기 위함. 
	// axi에서 값은 read하는 시간이 1cycle 느려지면,
	// BRAM 0 에서 read하는 경우가 아닐 때는 한 사이클 정도는 밀려도 되는건가?
	// arready는 arvalid에 영향을 받고 rvalid 또한 arvalid에 영향을 받음 
	// 상관없을 것 같음 
	assign S_AXI_RVALID		= axi_rvalid_d;	//reg         axi_rvalid;
    
    reg reg_mano_cpu_reset_n;

	always @(posedge S_AXI_ACLK) begin 
    	if(S_AXI_ARESETN == 1'b0 ) begin // sync reset_n
    		reg_mano_cpu_reset_n <= 1'b1;  
    	end else if (slv_reg0[31] == 1) begin
        	reg_mano_cpu_reset_n <= 1'b0;
    	end else if (slv_reg0[31] == 0) begin
        	reg_mano_cpu_reset_n <= 1'b1;
    	end 
	end

	assign mano_cpu_reset_n  = reg_mano_cpu_reset_n;
	
	// 이제 Master에서의 입력신호에 Slave 출력이 어떻게 나올지 always block을 써보자.
	// Slave 출력신호인 AWREADY 신호를 보겠다.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awready <= 1'b0;
	      aw_en 	  <= 1'b1; // 뭔지는 모르겠지만, 리셋시 이 신호가 1이 되는구나. 
	    end 
	  else
	    begin    
		//언제 axi_awready가 1이 되면 좋을까?
        //axi_awready가 0이고, S_AXI_AWVALID가 1이고, S_AXI_WVALID가 1이고, 위의
        //aw_en이 1일때겠지? 그러면 코드는 아래와 같이 짜야돼.
		//aw_en은 1틱만을 주기 위한 신호같다.
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) 
	        begin
	          axi_awready <= 1'b1;
	          aw_en <= 1'b0;
	        end
		//언제 1로 올라온 axi_awready가 0이 되면 좋을까?
        // write 했다! 를 알려주는 bvalid와, master에서 나오는 S_AXI_BREADY가 1일 때
	      else if (S_AXI_BREADY && axi_bvalid)
	        begin
	          aw_en 	  <= 1'b1;
	          axi_awready <= 1'b0;
	        end
	      else           
	        begin
	          axi_awready <= 1'b0;
	        end
	    end 
	end       


	// 이번엔 Slave 입력신호인 AWADDR (write할 주소) 신호를 보겠다.
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awaddr <= 0;
	    end 
	  else
	    begin    
		//언제 write할 주소를 reg로 캡처하면 좋을까?
        //axi_awready가 0이고, S_AXI_AWVALID가 1이고, S_AXI_WVALID가 1이고, 위의
        //aw_en이 1일때(1틱)면 그때의 awaddr은 쓸 주소가 돼. 그 순간 캡처해야해
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
	        begin
	          // Write Address latching 
	          axi_awaddr <= S_AXI_AWADDR; // 그때의 주소를 캡쳐 (래칭)
	        end
	    end 
	end       

	// Slave 출력신호인 WREADY 신호를 보겠다.
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_wready <= 1'b0; 
	    end 
	  else
	    begin    
	      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )  // write할 데이터가 나오고 있을 때 (valid)
	        begin
			//언제 axi_wready가 1이 되면 좋을까?
            //axi_awready와 같이 1이 되면 좋겠다. 
	          axi_wready <= 1'b1; // write 채널의 ready 신호가 1
	        end
	      else
	        begin
	          axi_wready <= 1'b0;
	        end
	    end 
	end       

// 데이터가 쓰이기 시작할 때는 언제일까?
// axi_wready,axi_awready가 1이고, S_AXI_WVALID,S_AXI_AWVALID또한 1일때이다. 
	assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID; // 데이터가 쓰이기 시작할 때 

// 데이터가 쓰이기 시작할 때 이므로 이때 register에 값을 적어주겠다. (always block으로)
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      slv_reg0 <= 0;
	      slv_reg1 <= 0;
	      slv_reg2 <= 0;
	      slv_reg3 <= 0;
	    end 
	  else begin
	    if (slv_reg_wren)
	      begin
	        case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
			// axi_awaddr는 32비트이고 16진수 4비트중 [3:2]만 건드림
            // -> 0x0000 0x0100 0x0200 0x0300 
	          2'h0:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	        // S_AXI_WSTRB는 4비트이고,
            // 여기서 만약 이 4비트가 1110이면, register에 32비트중 8비트는
            // Master에서 보낸 Data를 받지 않는다.
	                slv_reg0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 0 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          2'h1:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 1
	                slv_reg1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 4 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          2'h2:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 2
	                slv_reg2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 8 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          2'h3:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 3
	                slv_reg3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register c 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          default : begin
	                      slv_reg0 <= slv_reg0;
	                      slv_reg1 <= slv_reg1;
	                      slv_reg2 <= slv_reg2;
	                      slv_reg3 <= slv_reg3;
	                    end
	        endcase
	      end
	  end
	end    

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	wire clk = S_AXI_ACLK;
	wire reset_n = S_AXI_ARESETN;
	// BRAM0의 address를 register 주소 1000에 할당.
	wire [C_S_AXI_ADDR_WIDTH-1:0]	mem0_axi_addr = 'h8; // (1000) 4비트

	// BRAM0의 data를 	register 주소 1100에 할당.
	wire [C_S_AXI_ADDR_WIDTH-1:0]	mem0_axi_data = 'hc; // (1100) 4비트

	// Master에서 쓰는 데이터인 WDATA로 BRAM 0의 address 를 결정함.
	wire [C_S_AXI_DATA_WIDTH-1:0]	mem0_addr_reg = S_AXI_WDATA;

	// Master에서 쓰는 데이터인 WDATA로 BRAM 0의 data 를 결정함.
	wire [C_S_AXI_DATA_WIDTH-1:0]	mem0_data_reg = S_AXI_WDATA;

	// slv_reg_wren = 데이터가 쓰이기 시작할 때 (register에 값을 넣을 때)
	// master가 보낸 주소와 BRAM0의 address인 register 주소 1000 과 일치했을 때
	// 이때부터 BRAM0에 address는 Master에서 쓰는 데이터이다 (밑에 코드 참조) 
	wire mem0_addr_write_hit = slv_reg_wren && (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == mem0_axi_addr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]);
	// master에서 보낸 값이 1000이면, BRAM 0의 주소에 해당하는 register의 주소와 
	//일치하므로 address에 접근하겠다는 의미이다. 그러면
	// mem0_addr_write_hit가 켜짐. 그리고 그 다음에 입력하는 값이 예를 들어 90이면
	// "BRAM0의 90번지에 접근하겠다" 라는 말이 될 것임. 

	wire mem0_data_write_hit = slv_reg_wren && (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == mem0_axi_data[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]);
	// master에서 write address channel로 address를 보냄.
	// master에서 보낸 값이 1100이야 -> BRAM 0의 data(1100)에 접근하겠다 라는 의미
	// 이 때 mem0_data_write_hit 신호가 켜짐 -> 그리고 그 다음에 입력하는 값이 90이면
	// 이전 BRAM0의 주소에 90이라는 값을 write하겠다 라는 의미이다.

	wire mem0_data_read_hit = slv_reg_rden && (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == mem0_axi_data[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]);
	// master에서 ! read data ! channel로 data를 보냄.
	// master에서 보낸 값이 1100이야 -> BRAM 0의 data register address인(1100)에접근
	// 이때 mem0_data_read_hit 신호가 켜짐
	// 그러면 BRAM0에 있는 현재 주소에 있는 값을 읽을 수 있다.

	reg	[MEM0_ADDR_WIDTH-1:0] mem0_addr_cnt; // BRAM 0의 address를 의미한다.
	always @(posedge clk or negedge reset_n) begin
	    if(!reset_n) begin
	        mem0_addr_cnt <= 0;  // BRAM 0의 address가 0으로 초기화된다. 
	    end else if (mem0_addr_write_hit) begin
	        mem0_addr_cnt <= mem0_addr_reg; 
		// BRAM 0의 address를 master에서 보낼 것이다. 
	    end else if (mem0_data_write_hit) begin
	        mem0_addr_cnt <= mem0_addr_cnt + 1;
		// BRAM 0의 data를 write나 read할 때 BRAM 0의 주소는 자동으로 1 증가한다.
		end
	end


	// BRAM 0의 data를 read할 때는 어떤 모듈에서 address를 hw ip로 주는것이 아니라
	// master에서 입력한 주소를 토대로 그 주소의 data를 read한다.
	// 따라서 BRAM 0에서 데이터가 나올 때 1 cycle 늦게 나오도록 설계해야한다.
	reg slv_reg_rden_d;
	always @(posedge clk or negedge reset_n) begin
	    if(!reset_n) begin
			axi_rvalid_d	<= 'd0;
			slv_reg_rden_d	<= 'd0;
	    end else begin
			axi_rvalid_d	<= axi_rvalid;
			slv_reg_rden_d	<= slv_reg_rden;
	    end 
	end

	// BRAM0에 대한 memory interface를 assign 
	assign mem0_addr1 	= mem0_addr_cnt[MEM0_ADDR_WIDTH-1:0]			; 
	//output		[MEM0_ADDR_WIDTH-1:0] 	mem0_addr1,
	assign mem0_ce1		= mem0_data_write_hit || mem0_data_read_hit		;
	//output		 						mem0_ce1,
	assign mem0_we1		= mem0_data_write_hit 							;
	//output		 						mem0_we1,
	//input 		[MEM0_DATA_WIDTH-1:0]  	mem0_q1,
	assign mem0_d1		= mem0_data_reg									;
	//output		[MEM0_DATA_WIDTH-1:0] 	mem0_d1
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



	// Slave 출력신호인 BVALID, BRESP(00) 신호를 보겠다.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_bvalid  <= 0;
	      axi_bresp   <= 2'b0;
	    end 
	  else
	    begin    
		// 데이터의 전송이 이동할 때 
	      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) // 데이터의 전송이 끝났을 때 
	        begin
	          // indicates a valid write response is available
	          axi_bvalid <= 1'b1;
	          axi_bresp  <= 2'b0; // 'OKAY' response // 이건 나도 잘 모르지만 0일때 Okay라고 하네.
	        end                   // work error responses in future
	      else
	        begin
	          if (S_AXI_BREADY && axi_bvalid) 
        	// BVALID와 BREADY가 1이면, Write Response가 끝. 데이터 전송이 끝났다는 말
        	// 이 때 axi_bvalid를 0으로 낮춰야지   
	            begin
	              axi_bvalid <= 1'b0; 
	            end  
	        end
	    end
	end   


	// Slave 출력신호인 arready 신호를 보겠다.
	// AWREADY, WREADY는 봤고 나머지 하나인 ARREADY를 보자. 
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_arready <= 1'b0;
	      axi_araddr  <= 32'b0; // read해야하는 address도 0으로 초기화
	    end 
	  else
	    begin    
	      if (~axi_arready && S_AXI_ARVALID)
		// address read할 데이터는 나오지만 (vaild) 아직 받아들일 준비가 안되었을 때 
        //(~axi_arready) 이때 딱 read할 주소를 캡쳐해야해 -> 그 주소에 데이터를 넣을거야.
	        begin
	          // indicates that the slave has acceped the valid read address
	          axi_arready <= 1'b1;
	          // Read address latching
	          axi_araddr  <= S_AXI_ARADDR;
	        end
	      else
	        begin
	          axi_arready <= 1'b0;
	        end
	    end 
	end       

	//axi_rvalid = slave에서 read된 데이터가 나오고 있을 때 
	// Slave 출력신호인 RVALID 신호를 보겠다.
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rvalid <= 0;
	      axi_rresp  <= 0;
	    end 
	  else
	    begin    
		// read 전송하고 있는 중일 때 
	      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) 
	        begin
	          // Valid read data is available at the read data bus
	          axi_rvalid <= 1'b1;
	          axi_rresp  <= 2'b0; // 'OKAY' response
	        end   
		// 이미 axi_rvalid, S_AXI_RREADY가 1로 read 전송을 마쳤을 때 
	      else if (axi_rvalid && S_AXI_RREADY)
	        begin
	          // Read data is accepted by the master
	          axi_rvalid <= 1'b0;
	        end                
	    end
	end    

	//axi_rvalid = slave에서 read된 데이터가 나오고 있을 때 
	assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid; 
	// 위는 read된 데이터가 전송되기 전(~axi_rvalid)이고, 
	// read할 주소는 보내고 있을 때 (axi_arready)
	// 실제로 보면 axi_arready 이 신호가 먼저 나오고, axi_rvalid이 신호가 나중에 나옴

	// 이때 read data를 정하기 위해서 slv_reg_rden을 저 상황에 활성화주는 것 같음.
	// 바로바로 해줘야하므로 sync가 아닌 async logic으로 해주겠다.
	always @(*)
	begin
	      // Address decoding for reading registers
	      case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	        2'h0   : reg_data_out <= slv_reg0; // 0번지의 register 값을 받음
	        2'h1   : reg_data_out <= slv_reg1; // 4번지의 register 값을 받음
	        2'h2   : reg_data_out <= slv_reg2; // 8번지의 register 값을 받음
			// 0x08 -> BRAM 0의 adddress와 관련된 register
	        2'h3   : reg_data_out <= mem0_q1[C_S_AXI_DATA_WIDTH-1:0];
			//input 		[MEM0_DATA_WIDTH-1:0]  	mem0_q1,
			// -> BRAM0에서 나온 read 데이터이므로 
			// 0x0C -> BRAM 0의 data와 관련된 register 이므로 mem0_q1이 나와야함
			//2'h3   : reg_data_out <= slv_reg3; // c번지의 register 값을 받음
	        default : reg_data_out <= 0;
	      endcase
	end

	// read 데이터가 정해지면 1 clock 뒤에 그 값이 나와야겠네 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rdata  <= 0;
	    end 
	  else
	    begin    
	      // When there is a valid read address (S_AXI_ARVALID) with 
	      // acceptance of read address by the slave (axi_arready), 
	      // output the read dada 
	      if (slv_reg_rden_d)
	        begin
	          axi_rdata <= reg_data_out;     // register read data
	        end   
	    end
	end    

	endmodule
