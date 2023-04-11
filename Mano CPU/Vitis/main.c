#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include "xparameters.h"
#include "xil_io.h"    // Xil_in, out을 쓰기 위한 header
#include <assert.h>
#include "time.h"

#define WRITE 1
#define RESET 2
#define RUN 3
#define READ 4
#define AXI_DATA_BYTE 4

#define CTRL_REG 0
#define MEM0_ADDR_REG 2 // 4 x 2 = 8 = 0x08 번지 ->  BRAM0의 ADDR register 주소
#define MEM0_DATA_REG 3 // 4 x 3 = 12 = 0x0C 번지 -> BRAM0의 DATA register 주소

int main() {
      int run_signal;
      int i;
      int read_data;
      int control; // Write or Read
      int addr_num; // BRAM 0 Address for Read // u32를 맞춰주기 위해 uint32_t를 사용
      u32 data[] = {
            0x00007108,
            0x00007200,
            0x0000306e,
            0x00007164,
            0x0000306f,
            0x00002064,
            0x0000606f,
            0x0000906f,
            0x0000606e,
            0x00004006,
            0x00003063,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x00000000,
            0x0000004d,
            0x00000064,
            0x00000037,
            0x00000042,
            0x0000004d,
            0x00000058,
            0x00000063,
            0x0000004f,
            0x00000043,
            0x0000005a
      };
      while(1){
         // 사용자 입력: 1을 누르면 BRAM 0에 Write, 2를 누르면 BRAM 0을 Read 할 수 있다.
         printf("======= Hello Mano CPU ======\n");
         printf("1. WRITE BRAM 0 \n"); // AXI-Lite를 통해서 BRAM0에다가 Write하는 과정
         printf("2. MANO CPU reset \n"); // register 0번지 MSB를 1로 해서 Mano CPU를 reset 해줌
         printf("3. MANO CPU run \n"); // register 0번지 MSB를 0로 해서 Mano CPU를 run 해줌
         printf("4. READ BRAM 0 \n");   // AXI-Lite를 통해서 BRAM0에서 Read하는 과정
         scanf("%d",&control);

         if(control == WRITE) {
         Xil_Out32((XPAR_MANO_CPU_WRAPPER_0_BASEADDR) + (CTRL_REG*AXI_DATA_BYTE), (u32)(0)); // Clear
          // Data Loading to BRAM 0
          Xil_Out32((XPAR_MANO_CPU_WRAPPER_0_BASEADDR) + (MEM0_ADDR_REG*AXI_DATA_BYTE), (u32)(0x00000000));
            // BRAM 0의 address를 0으로 초기화한다. 이땐 address가 자동으로 증가하지 않는다.

            //////////////////// BRAM 0번지부터 109번지까지 명령어, 학생성적 넣는 코드 ///////////////////////
            // 0x0C번지의 register에 write_buf[0] 부터 write_buf[109]까지 값을 넣음
          for(i=0; i< 110 ; i++){
             Xil_Out32((XPAR_MANO_CPU_WRAPPER_0_BASEADDR) + (MEM0_DATA_REG*AXI_DATA_BYTE), (u32) data[i]); // Clear
          }
            // -> hw ip 코드가 값을 넣으면 자동으로 주소가 1 증가하므로 BRAM 1번지부터 110번지까지 값이 저장됨. -> 오류 발생
            ////////////////////////////////////////////////////////////////////////////////////////////

            printf("\nBRAM 0 Write Done\n\n");
         }
         else if (control == RESET){
            Xil_Out32((XPAR_MANO_CPU_WRAPPER_0_BASEADDR) + (CTRL_REG*AXI_DATA_BYTE), (u32)(0x80000000)); // MSB run
            printf("\nMano CPU reset complete\n");
         }
         else if (control == RUN){
            Xil_Out32((XPAR_MANO_CPU_WRAPPER_0_BASEADDR) + (CTRL_REG*AXI_DATA_BYTE), (u32)(0)); // MSB run
            printf("\nMano CPU run complete\n");
         }
         else if (control == READ){
            run_signal = Xil_In32((XPAR_MANO_CPU_WRAPPER_0_BASEADDR) + (CTRL_REG*AXI_DATA_BYTE));
            printf("\n%x\n", run_signal);
            printf("Which address of BRAM 0 do you want to know?\n");
            scanf("%d",&addr_num);
            Xil_Out32((XPAR_MANO_CPU_WRAPPER_0_BASEADDR) + (MEM0_ADDR_REG*AXI_DATA_BYTE), (u32)(addr_num));
            // 값을 입력받으면, 그 값으로 BRAM 0의 주소를 초기화한다.
            read_data = Xil_In32((XPAR_MANO_CPU_WRAPPER_0_BASEADDR) + (MEM0_DATA_REG*AXI_DATA_BYTE));
            printf("\nBRAM 0 Address : %d value : %d\n\n", addr_num, read_data );
         }
      }
      return 0;
}
