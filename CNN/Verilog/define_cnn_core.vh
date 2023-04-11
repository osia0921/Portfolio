
parameter CI = 3;   // input channel
parameter CO = 16;  // output channel
parameter KX = 3;   // kernel size x
parameter KY = 3;   // kernel size y

parameter I_FM_BW = 8; // input feature map BW 
parameter I_W_BW  = 8; // input weight BW
parameter I_B_BW  = 8; // input bias BW

parameter M_BW    = 16;  // i_fmap과 kernel을 곱한 값
parameter AC_K_BW = 20;  // i_fmap과 kernel을 곱한 값들을 모두 더한 값
parameter ACI_BW  = 22;  // i_fmap 3차원 x weight 3차원 후 모두 더한 값
parameter AB_BW   = 23;  // ACI_BW + bias (#1). 
parameter O_F_BW  = 23; // output feature map BW (activation function X)

parameter   O_F_ACC_BW  = 27; // for demo
