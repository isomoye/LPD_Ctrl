module CalcAllDistances(
input  logic clk,
input  logic reset,
//start and ready
input  logic start,
output logic ready,
//PNL signals
input  logic [PNL_BRAM_DBITS_WIDTH_NB-1:0] PNL_BRAM_dout,
output logic [PNL_BRAM_DBITS_WIDTH_NB-1:0] PNL_BRAM_addr,
output logic [PNL_BRAM_DBITS_WIDTH_NB-1:0] PNL_BRAM_din,
output logic [0:0] PNL_BRAM_we,

output logic calcDist_start,
input logic  calcDist_ready,



input logic [PNL_BRAM_ADDR_SIZE_NB - 1:0] NumVals,
input logic [PNL_BRAM_ADDR_SIZE_NB - 1:0] Num_clusters,
input logic [PNL_BRAM_ADDR_SIZE_NB - 1:0] Num_Dims,

output logic [PNL_BRAM_ADDR_SIZE_NB - 1:0] P1_addr,
output logic [PNL_BRAM_ADDR_SIZE_NB - 1:0] P2addr,

input logic [PNL_BRAM_ADDR_SIZE_NB - 1:0] Nu

input logic [PNL_BRAM_ADDR_SIZE_NB - 1:0] TGT_BRAM_addr
);












endmodule