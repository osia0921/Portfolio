
`timescale 1 ns / 1 ps

	module axi4_lite_test #
	(
		// Users to add parameters here
		parameter   CNN_PIPE    = 5,
		parameter   CI          = 3,
		parameter   CO          = 16,
		parameter	KX			= 3,
		parameter	KY			= 3,
		
		parameter   I_F_BW      = 8,
		parameter   W_BW        = 8, // Weight BW
		parameter   B_BW        = 8, // Bias BW
		
		parameter   M_BW        = 16, 
		parameter   AK_BW       = 20, // M_BW + log(KY*KX) accum kernel 
		parameter   ACI_BW		= 22, // AK_BW + log (CI)
		parameter   AB_BW       = 23,
		parameter   O_F_BW      = 23, // No Activation, So O_F_BW == AB_BW
		
		parameter   O_F_ACC_BW  = 28, // for demo
		// User parameters ends
		// Do not modify the parameters beyond this line

		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		// 레지스터의 크기가 32bit임을 파라미터로 설정
		parameter integer C_S_AXI_ADDR_WIDTH	= 6
		// 레지스터의 주소를 6비트로 표현한다 -> 000000 -> 000100 -> 000200 -> 000300 -> ...
	)
	(
	    // Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal.(Active LOW)
		input wire  S_AXI_ARESETN,
		
		//Write Address Channel (AW)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		input wire [2 : 0] S_AXI_AWPROT, 
		input wire  S_AXI_AWVALID, 
		output wire  S_AXI_AWREADY, 
		
		//Write Data Channel (W)
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,    
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
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

		// User ports
		// SW로부터 AXI4-Lite interface를 통해 i_fmap, weight, bias 등등 신호가 들어옴.
		// 어떻게? -> slv_reg0~6의 값을 이 모듈을 통해 SW(PS)에서 Vitis tool로 직접 넣어줌으로써 (펌웨어)
		
	    output 						o_data_en, // 유효하다는 신호는 PS 신호를 통해 register로 들어올 것이기 때문에 이를 HW Core로 넘겨야함. 
	    output [I_F_BW-1 :0] 		o_f_value, // input feature 값은 PS 신호를 통해 register로 들어올 것이기 때문에 이를 HW Core로 넘겨야함. 
	    output [W_BW-1 :0]			o_w_value, // weight 값은 PS 신호를 통해 register로 들어올 것이기 때문에 이를 HW Core로 넘겨야함. 
	    output [B_BW-1 :0] 			o_b_value, // bias 값은 PS 신호를 통해 register로 들어올 것이기 때문에 이를 HW Core로 넘겨야함. 
	    
	    input  						i_result_en, // CNN 연산된 값이 유효하다는 신호는 HW Core로부터 받아서 register로 저장해야 PS에서 볼 수 있다.
        input  [O_F_BW-1:0] 		i_result_0,  // o_fmap의 첫포인트는 HW Core로부터 받아서 register로 저장해야 PS에서 볼 수 있다.
        input  [O_F_ACC_BW-1:0] 	i_result_acc // CNN 연산된 값을 모두 더한 값을 HW Core로부터 받아서 register로 저장해야  PS에서 볼 수 있다.
	);

	// AXI4LITE signals // register를 아래와 같이 선언해놓았고, 
	//register는 어떻게 사용이 되나면, signals 들을 캡쳐 또는 래칭할 때 사용한다.
	//코드로 Slave에서 나와야하는 신호들
	reg  	                        axi_awready;
	reg  	                        axi_wready;
	reg [1 : 0] 	                axi_bresp;
	reg  	                        axi_bvalid;
	reg  	                        axi_arready;
	reg [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
	reg [1 : 0] 	                axi_rresp;
	reg  	                        axi_rvalid;
	
	//Master에서 나오는 신호이며, 주소를 의미함
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;

	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
	// 2인 이유: 하위 2비트를 제거한다는 의미이다. (나중에 코드로 나옴)
	// register의 address가 4씩 증가하므로 0x000, 0x100, 0x200, 0x300 ... 으로 가겠지
	// 하위 2비트는 왜 제거해? 주소 1개당 8비트의 data를 가지니까 하위 2비트 제거 -> 4개 주소를 가짐 -> 32bit 표현가능
	localparam integer OPT_MEM_ADDR_BITS = 3; // 000100 -> 앞의 3비트를 자르기 위해 쓰는 것 -> 100


	//-- Number of Slave Registers 16
	// 이 레지스터에 우리가 axi4-interface를 통해서 값을 쓰고 읽고 하는 것이다. 
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg0; // RW : [0]    data_en
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg1; // RW : [31:0] f_value
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg2; // RW : [31:0] w_value
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg3; // RW : [31:0] b_value
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg4; // RO : [0] result_en
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg5; // RO : [31:0] result_0
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg6; // RO : [31:0] result_acc
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg7;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg8;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg9;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg10;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg11;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg12;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg13;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg14;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg15;
	
	wire	 slv_reg_rden; // 밑에 코드에서 역할을 알게 될 것임.
	wire	 slv_reg_wren; // 밑에 코드에서 역할을 알게 될 것임.
	
	// 레지스터에서 나오는(읽힌) 데이터
	reg [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;
	
	integer	 byte_index;
	reg	 aw_en; // 한클락을 주기 위해 필요한 신호?로 보임 

	wire [C_S_AXI_DATA_WIDTH-1:0]	 result_32b;
	
	
    //코드로 Slave에서 나와야하는 신호들을 Output 신호와 연결시켜줌
	assign S_AXI_AWREADY	= axi_awready   ; //reg         axi_awready;
	assign S_AXI_WREADY	    = axi_wready    ; //reg         axi_wready;
	assign S_AXI_BRESP	    = axi_bresp     ; //reg [1:0]   axi_bresp;
	assign S_AXI_BVALID	    = axi_bvalid    ; //reg         axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready   ; //reg         axi_arready;
	assign S_AXI_RDATA	    = axi_rdata     ; //reg         axi_rdata;
	assign S_AXI_RRESP	    = axi_rresp     ; //reg         axi_rresp;
	assign S_AXI_RVALID	    = axi_rvalid    ; //reg         axi_rvalid;


    // 이제 Master에서의 입력신호에 Slave 출력이 어떻게 나올지 always block을 써보자.
	// Slave 출력신호인 AWREADY 신호를 보겠다.	
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awready <= 1'b0;
	      aw_en       <= 1'b1; // 뭔지는 모르겠지만, 리셋시 이 신호가 1이 되는구나. 
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
	              aw_en <= 1'b1;
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
	      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en ) // write할 데이터가 나오고 있을 때 (valid)
	        begin
	        //언제 axi_wready가 1이 되면 좋을까?
            //axi_awready와 같이 1이 되면 좋겠다. (위에 코드보면 똑같은 조건)
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
	// Slave가 받을 준비도 되고 (ready), Master가 보낸 Data가 유효할 때 (Valid)


// 데이터가 쓰이기 시작할 때 이므로 이때 register에 값을 적어주겠다. (always block으로)
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      slv_reg0 <= 0;
	      slv_reg1 <= 0;
	      slv_reg2 <= 0;
	      slv_reg3 <= 0;
	      //slv_reg4 <= 0;
	      //slv_reg5 <= 0;
	      //slv_reg6 <= 0;
	      slv_reg7 <= 0;
	      slv_reg8 <= 0;
	      slv_reg9 <= 0;
	      slv_reg10 <= 0;
	      slv_reg11 <= 0;
	      slv_reg12 <= 0;
	      slv_reg13 <= 0;
	      slv_reg14 <= 0;
	      slv_reg15 <= 0;
	    end 
	  else begin
	    if (slv_reg_wren)
	      begin
	        case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] ) // axi_awaddr[5:2]
	        // axi_awaddr는 32비트니까 16진수로 8비트네
	        // 16진수 8비트중 [5:2]만 건드림 -> 4비트
	        // 그래서 앞에 3비트 없애고, 하위 2비트를 없애는 거구나 (OPT_MEM_ADDR_BITS, ADDR_LSB)
            // -> 0x00000000 = 0000, 0x00000100 = 0001, 0x00000200 = 0002, 0x00000300 = 0003
	          4'h0:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // S_AXI_WSTRB는 4비트이고,
                    // 여기서 만약 이 4비트가 1110이면, register에 32비트중 8비트는
                    // Master에서 보낸 Data를 받지 않는다.
	                slv_reg0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 0 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          4'h1:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 1
	                slv_reg1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 4 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          4'h2:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 2
	                slv_reg2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 8 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          4'h3:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 3
	                slv_reg3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 12 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          4'h4:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 4
	                //slv_reg4[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 16 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          4'h5:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 5
	                //slv_reg5[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 20 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          4'h6:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 6
	                //slv_reg6[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 24 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          4'h7:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 7
	                slv_reg7[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 28 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          4'h8:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 8
	                slv_reg8[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 32 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          4'h9:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 9
	                slv_reg9[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 36 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          4'hA:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 10
	                slv_reg10[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 40 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          4'hB:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 11
	                slv_reg11[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 44 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          4'hC:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 12
	                slv_reg12[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 48 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          4'hD:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 13
	                slv_reg13[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 52 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          4'hE:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 14
	                slv_reg14[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 56 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          4'hF:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 15
	                slv_reg15[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8]; // register 60 번지에 write 할 32비트의 값(데이터)을 넣음
	              end  
	          default : begin
	                      slv_reg0 <= slv_reg0;
	                      slv_reg1 <= slv_reg1;
	                      slv_reg2 <= slv_reg2;
	                      slv_reg3 <= slv_reg3;
//	                      slv_reg4 <= slv_reg4;
//	                      slv_reg5 <= slv_reg5;
//	                      slv_reg6 <= slv_reg6;
	                      slv_reg7 <= slv_reg7;
	                      slv_reg8 <= slv_reg8;
	                      slv_reg9 <= slv_reg9;
	                      slv_reg10 <= slv_reg10;
	                      slv_reg11 <= slv_reg11;
	                      slv_reg12 <= slv_reg12;
	                      slv_reg13 <= slv_reg13;
	                      slv_reg14 <= slv_reg14;
	                      slv_reg15 <= slv_reg15;
	                    end
	        endcase
	      end
	  end
	end    



    // Slave 출력신호인 BVALID, BRESP(00) 신호를 보겠다.
    // Slave가 Master로부터 유효한 Address, Data를 잘 받았을 때 Master로 보내는 Response 신호 
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
	        // BREADY신호는 Master에서 Ready가 됐다는 신호이다. 즉, Slave의 Resp 신호를 받을 준비가 되었다. 
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
	// Master가 Slave에게서 주소를 받을 준비가 되었을 때 (axi_arready)
	// 실제로 보면 axi_arready 이 신호가 먼저 나오고, axi_rvalid이 신호가 나중에 나옴 (당연한 것)
	
	// 이때 read data를 정하기 위해서 slv_reg_rden을 저 상황에 활성화주는 것 같음.
	// 바로바로 해줘야하므로 sync가 아닌 async logic으로 해주겠다.
	always @(*)
	begin
	      // Address decoding for reading registers
	      case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	        4'h0   : reg_data_out <= slv_reg0;  //  0번지의 register 값을 받음
	        4'h1   : reg_data_out <= slv_reg1;  //  4번지의 register 값을 받음
	        4'h2   : reg_data_out <= slv_reg2;  //  8번지의 register 값을 받음
	        4'h3   : reg_data_out <= slv_reg3;  // 12번지의 register 값을 받음
	        4'h4   : reg_data_out <= slv_reg4;  // 16번지의 register 값을 받음
	        4'h5   : reg_data_out <= slv_reg5;  // 20번지의 register 값을 받음
	        4'h6   : reg_data_out <= slv_reg6;  // 24번지의 register 값을 받음
	        4'h7   : reg_data_out <= slv_reg7;  // 28번지의 register 값을 받음
	        4'h8   : reg_data_out <= slv_reg8;  // 32번지의 register 값을 받음
	        4'h9   : reg_data_out <= slv_reg9;  // 36번지의 register 값을 받음
	        4'hA   : reg_data_out <= slv_reg10; // 40번지의 register 값을 받음
	        4'hB   : reg_data_out <= slv_reg11; // 44번지의 register 값을 받음
	        4'hC   : reg_data_out <= slv_reg12; // 48번지의 register 값을 받음
	        4'hD   : reg_data_out <= slv_reg13; // 52번지의 register 값을 받음
	        4'hE   : reg_data_out <= slv_reg14; // 56번지의 register 값을 받음
	        4'hF   : reg_data_out <= slv_reg15; // 60번지의 register 값을 받음
	        default : reg_data_out <= 0;
	      endcase
	end



	// read 데이터가 유효하다는 신호(rvalid) 1 clock 전에 유효한 read data 값이 나와야겠네 
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
	      if (slv_reg_rden)
	        begin
	          axi_rdata <= reg_data_out;     // register read data
	        end   
	    end
	end    

	// Add user logic here
	assign o_data_en   = slv_reg0[0];
	// slv_reg0[0]을 PS영역에서 (Vitis에서 SW로) 값을 설정함으로써 input 값 유효하다는 것을 HW Core에게 알려줄 것이다.              
	assign o_f_value   = slv_reg1[0 +: I_F_BW];
	// 32bit slv_reg1중 8bit를 i_fmap 값으로 PS영역에서 값을 설정함으로써 8비트씩 input feature map을 받아 HW Core로 넘겨줄 수 있다.
	assign o_w_value   = slv_reg2[0 +: W_BW]; 
	// 32bit slv_reg2중 8bit를 weight 값으로 PS영역에서 값을 설정함으로써 8비트씩 weight의 받아 HW Core로 넘겨줄 수 있다.
	assign o_b_value   = slv_reg3[0 +: B_BW]; 
	// 32bit slv_reg3중 8bit를 bias 값으로 PS영역에서 값을 설정함으로써 8비트씩 weight의 받아 HW Core로 넘겨줄 수 있다.
	
	
	assign result_32b = {31'b0, i_result_en};

	always @(*) begin
		slv_reg4 = result_32b; 
		// HW Core(PL)로부터 출력 값이 유효한지에 대한 신호를 받아 slv_reg4의 LSB에 넣는다. 
		slv_reg5 = {{32-O_F_BW{1'b0}}, i_result_0}; 
		// HW Core(PL)로부터 output fmap의 한 포인트 값을 받아 slv_reg5에 저장 -> PS에서 확인할 수 있다.
		slv_reg6 = {{32-O_F_ACC_BW{1'b0}}, i_result_acc};
		// HW Core(PL)로부터 output fmap을 다 더한 값을 받아 slv_reg6에 저장 -> PS에서 확인할 수 있다.
	end
	// User logic ends

	endmodule

