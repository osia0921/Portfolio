`timescale 1ns / 1ps

module mano_cpu
#(
        parameter DWIDTH = 32   ,
        parameter AWIDTH = 12   ,
        parameter MEM_SIZE = 4096
        //parameter DWIDTH = 16 (data_mover_bram)
)
(
    input                           clk,
    input                           reset_n,
    input       [DWIDTH-1:0]        dout, // SRAM의 특정 주소에 대한 memory값을 Read 
    output reg  [DWIDTH-1:0]        din,  // SRAM의 특정 주소에 Write하기 위한 값 
    output reg                      we,
    output reg  [AWIDTH-1:0]        ar, // 12 bit address register
    output reg  [DWIDTH-1:0]        ac // 16 bit accumulator (data_mover_bram)
);

reg [AWIDTH-1:0] pc             ; // 12 bit program counter
reg [DWIDTH-1:0] ir             ; // 16 bit instruction register 
//CPU가 명령을 수행하기 위해 메모리 상에서 명령어를 읽어오는 과정
//15bit -> indirect addressing, 14:12 -> Opcode 

reg [DWIDTH-1:0] dr; // 16 bit data register 
//reg [DWIDTH-1:0] ac; // 16 bit accumulator
reg [7:0]            d ; // for 3 - 2^3 decoder
reg [3:0]            sc; 
reg [9:0]            t ; // time (clock)
reg                  e ; // carry 
reg                  i ; // d[7] for considering reference

// Combinational Logic 
always @ (*) begin
    case(sc)
        4'b0000 : t <= 10'b00_0000_0001; // sc = 0 (T0)
        4'b0001 : t <= 10'b00_0000_0010; // sc = 1 (T1)
        4'b0010 : t <= 10'b00_0000_0100; // sc = 2 (T2)
        4'b0011 : t <= 10'b00_0000_1000; // sc = 3 (T3)
        4'b0100 : t <= 10'b00_0001_0000; // sc = 4 (T4)
        4'b0101 : t <= 10'b00_0010_0000; // sc = 5 (T5)
        4'b0110 : t <= 10'b00_0100_0000; // sc = 6 (T6)
        4'b0111 : t <= 10'b00_1000_0000; // sc = 7 (T7)
        4'b1000 : t <= 10'b01_0000_0000; // sc = 8 (T8)
        default: t <= 10'b10_0000_0000;  // sc = 9 (T9)
    endcase    
end

// Sequential Logic
always @ (posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        //t  <= 9'd1;
        sc <= 4'd0;
        e  <= 1'd0;
        dr <= 32'd0; // dr <= 16'd0; (data_mover_bram)
        ar <= 12'd0;
        pc <= 12'd0;
        ir <= 32'd0; // ir <= 16'd0; (data_mover_bram)
        ac <= 32'd0; // ac <= 16'd0; (data_mover_bram)
        we <= 0;
    end
    
////////////////////////////////// T0 ////////////////////////////////////////
    else if(t[0] == 1) begin
            ar <= pc;
            sc <= sc + 1; // for next step 
            we <= 0; // 여기서 read로 바꾸어주지 않으면, STA같은 명령어 수행 때, T0 (AR <- PC)에서 AR에 해당되는 메모리값에 저절로 쓰이게 된다.
    end
////////////////////////////////// T1 ////////////////////////////////////////
    else if (t[1] == 1) begin
        pc <= pc + 1;
        sc <= sc + 1; // for next step
    end
////////////////////////////////// T2 ////////////////////////////////////////
    else if (t[2] == 1) begin
        ir <= dout; // 메모리에 있는 걸 가져오므로 초기값 세팅이 we = 0으로 되있어야함.
        sc <= sc + 1; // for next step
    end
////////////////////////////////// T3 ////////////////////////////////////////
    else if (t[3] == 1) begin
        i  <= ir [15];
        ar <= ir [11:0];
        case ({ir[14], ir[13], ir[12]})
            3'b000 : d <= 8'b0000_0001;
            3'b001 : d <= 8'b0000_0010;
            3'b010 : d <= 8'b0000_0100;
            3'b011 : d <= 8'b0000_1000;
            3'b100 : d <= 8'b0001_0000;
            3'b101 : d <= 8'b0010_0000;
            3'b110 : d <= 8'b0100_0000;
            3'b111 : d <= 8'b1000_0000;
            default: d <= 8'b0000_0000;
        endcase
        sc <= sc + 1; // for next step 
    end
////////////////////////////////// T4 ////////////////////////////////////////
    else if (t[4] == 1) begin
/////////////////////////////Register - reference(T4)/////////////////////////
        if(d[7] && ~i) begin
            casex({ar})
            12'h800 : ac <= 16'd0           ;  // CLA = 7800 (ir)
            12'h400 : e  <= 1'd0            ;  // CLE = 7400 (ir) 
            12'h200 : ac <= ~ac             ;  // CMA = 7200 (ir)
            12'h1xx : ac <= ar[7:0]         ;  // LDC = 71xx (ir)
            12'h080 : begin                    // CIR = 7080 (ir)
                      ac <= {e, ac[15:1]}   ;
                      e  <= ac[0]           ;
                      end    
            12'h040 : begin                    // CIL = 7040 (ir)
                      ac <= {ac[14:0], e}   ;  
                      e  <= ac[15]          ;
                      end
            12'h020 : ac <= ac + 1          ;  // INC = 7020 (ir)
            12'h010 : if(ac[15] == 0) begin    // SPA = 7010 (ir)
                      pc <= pc + 1          ;
                      end
            12'h008 : if(ac[15] == 1) begin    // SNA = 7008 (ir)
                      pc <= pc + 1          ;
                      end
            12'h004 : if(ac == 16'd0) begin    // SZA = 7004 (ir)
                      pc <= pc + 1          ;
                      end
            12'h002 : if(e == 0)      begin    // SZE = 7002 (ir)
                      pc <= pc + 1          ;
                      end
            endcase
            sc <= 4'd0; // step is reset 
        end
/////////////////////////////Memory - reference(T4)/////////////////////////
        else if(~(d[7])) begin  // doing nothing
            sc <= sc + 1;
        end
    end
///////////////////////// T5 (only Memory - reference)//////////////////////
    else if (t[5] == 1) begin
        if(i) begin // indirecting addressing
            ar <= dout[11:0]; 
            sc <= sc + 1; // for next step 
        end
        else if(~i) begin
            sc <= sc + 1; // for next step 
        end
    end
///////////////////////// T6 (only Memory - reference)//////////////////////
    else if (t[6] == 1) begin // doing nothing
        sc <= sc + 1;
        if((d[0]) || (d[1]) || (d[2]) || (d[6])) begin // AND or ADD or LDA or ISZ -> T7 때 Read 해야 하므로
            we <= 0; // Read
        end
    end
///////////////////////// T7 (only Memory - reference)//////////////////////
    else if (t[7] == 1) begin
        if(d[0]) begin      // AND to AC
            dr <= dout;
            sc <= sc + 1; // for next step 
        end
        else if(d[1]) begin      // ADD to AC
            dr <= dout;     
            sc <= sc + 1; // for next step 
        end
        else if(d[2]) begin      // LDA to AC
            dr <= dout;    
            sc <= sc + 1; // for next step 
        end
        else if(d[3]) begin      // STORE AC
            we <= 1; // write는 latency가 없으므로 T7에 해도 됨.
            din <= ac; 
            sc <= 4'd0; // step is reset  
        end
        else if(d[4]) begin      // BUN : Branch Unconditionally
            pc <= ar; 
            sc <= 4'd0; // step is reset  
        end
        else if(d[5]) begin      // BSA : Branch and Save Return Address
            we <= 1; // write는 latency가 없으므로 T7에 해도 됨.
            din <= pc; 
            ar  <= ar + 1;  
            sc <= sc + 1; // for next step 
        end
        else if(d[6]) begin      // ISZ : Increment and Skip if Zero
            dr <= dout; 
            sc <= sc + 1; // for next step 
        end
    end
///////////////////////// T8 (only Memory - reference)//////////////////////
    else if (t[8] == 1) begin
        if(d[0]) begin      // AND to AC
            ac <= ac & dr;
            sc <= 4'd0; // step is reset  
        end
        else if(d[1]) begin      // ADD to AC
            ac <= ac + dr;
            sc <= 4'd0; // step is reset  
        end
        else if(d[2]) begin      // LDA to AC
            ac <= dr;
            sc <= 4'd0; // step is reset  
        end
        else if(d[5]) begin      // BSA : Branch and Save Return Address
            pc <= ar;
            sc <= 4'd0; // step is reset  
        end
        else if(d[6]) begin      // ISZ : Increment and Skip if Zero
            dr <= dr + 1;
            sc <= sc + 1; // for next step 
        end
    end
///////////////////// T9 (only Memory - reference - BUN)//////////////////////
    else if (t[9] == 1) begin
        we  <= 1; // write는 latency가 없으므로 T9에 해도 됨.
        din <= dr;
        if (dr == 0) begin
            pc <= pc + 1;
        end
        sc <= 4'd0; // step is reset  
    end
end
endmodule
