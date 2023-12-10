//--------------------------------------------------------------------------------
// Company: University of New Mexico
// Engineer: Professor Jim Plusquellic, Copyright Univ. of New Mexico
// 
// Create Date:
// Design Name: 
// Module Name:    DataTypes_pck - Behavioral 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//--------------------------------------------------------------------------------

// ========================
// INPUT/OUTPUT (IO) REGION
// ========================
// Input points consist of 16-bit fixed-point coordinates, with 4 bits of precision, ORIGINAL (unscaled) values limited to be between +/-2047.
`define COORD_SIZE_INT_BITS_NB (12)
`define COORD_SIZE_FCT_BITS_NB (4)
`define COORD_SIZE_BITS_NB (`COORD_SIZE_INT_BITS_NB + `COORD_SIZE_FCT_BITS_NB)
`define COORD_SIZE_BITS_LB (4)

// Set max number of points to 1024. This yields 32,768 bits (POINT_SIZE_BITS_NB * 1024) = 32*1024 = 32,768 bits, currently
`define MAX_NUM_POINTS_NB (1024)
`define MAX_NUM_POINTS_LB (10)

// Set max number of dimensions (number of coords/point) to 2, currently.
`define MAX_NUM_DIMS_NB (2)
`define MAX_NUM_DIMS_LB (1)

// Set maximum number of clusters to 256, currently. We will allocate 8-bits for storing each cluster number to make it a power-of-two for 
// easy fetching from BRAM. Actual number of clusters will be limited to 32 (2**5) -- see below -- because of memory limits.
`define CLUSTER_SIZE_BITS_NB (8)
`define CLUSTER_SIZE_BITS_LB (3)
`define MAX_NUM_CLUSTERS_NB (`CLUSTER_SIZE_BITS_NB)
`define MAX_NUM_CLUSTERS_LB (`CLUSTER_SIZE_BITS_LB)

// Set ACTUAL maximum number of clusters to 32, because of memory limits and requirements for DISTANCE CALC below. 
//    ZYBO Z7-10,  270KB, 276,480 bytes or 2,211,840 bits
//    CORA Z7-07S, 225KB, 230,400 bytes or 1,843,200 bits
`define ACTUAL_CLUSTER_SIZE_BITS_NB (5)
`define ACTUAL_CLUSTER_SIZE_BITS_LB (3)
`define ACTUAL_MAX_NUM_CLUSTERS_NB (2 ** `ACTUAL_CLUSTER_SIZE_BITS_NB)
`define ACTUAL_MAX_NUM_CLUSTERS_LB (`ACTUAL_CLUSTER_SIZE_BITS_NB)

// 2*16 = 32 bits 
`define POINT_SIZE_BITS_NB (`MAX_NUM_DIMS_NB * `COORD_SIZE_BITS_NB)
`define POINT_SIZE_BITS_LB (`MAX_NUM_DIMS_LB + `COORD_SIZE_BITS_LB)


// IO_BRAM DIMENSIONS: Do NOT MAKE LESS THAN 16-bits wide
`define IO_BRAM_WORD_SIZE_BITS_NB (32)
`define IO_BRAM_WORD_SIZE_BITS_LB (5)

// 32/16 = 2 coordinates/word currently
`define IO_BRAM_NUM_COORDS_PER_WORD (`IO_BRAM_WORD_SIZE_BITS_NB/`COORD_SIZE_BITS_NB)

// 32/8 = 4 clusters/word currently
`define IO_BRAM_NUM_CLUSTERS_PER_WORD (`IO_BRAM_WORD_SIZE_BITS_NB/`CLUSTER_SIZE_BITS_NB)

// Region: Input points: 0 to (1024-1): 2*16*1024/32 = 1024 32-bit words currently.
`define POINT_LADDR (0)
`define POINT_HADDR ((`MAX_NUM_DIMS_NB * `COORD_SIZE_BITS_NB * `MAX_NUM_POINTS_NB)/`IO_BRAM_WORD_SIZE_BITS_NB)

// Region: Final cluster assignment: 1024 to (1280-1): 8-bit unsigned integer, 8*1024/32 = 256
`define FCLUSTER_LADDR (`POINT_HADDR)
`define FCLUSTER_HADDR (`FCLUSTER_LADDR + (`CLUSTER_SIZE_BITS_NB * `MAX_NUM_POINTS_NB)/`IO_BRAM_WORD_SIZE_BITS_NB)

// Region: Final centroids: 1280 to (1536-1): 2*16*256/32 = 256
`define FCENTROID_LADDR (`FCLUSTER_HADDR)
`define FCENTROID_HADDR (`FCENTROID_LADDR + (`MAX_NUM_DIMS_NB * `COORD_SIZE_BITS_NB * `MAX_NUM_CLUSTERS_NB)/`IO_BRAM_WORD_SIZE_BITS_NB)

// Whole region is 1536 words in size. 11-bit address allows upto 2048 words.
`define IO_BRAM_ADDR_SIZE_BITS_NB (11)
`define IO_BRAM_NUM_WORDS_NB (`FCENTROID_HADDR)

// ========================
// DISTANCE CALC (DC) REGION
// ========================

// Distance array is large because it stores the sum of the (x,y) distances SQUARED (x1-x2)*(x1-x2) + (y1-y2)*(y1-y2) for each point (upto 1024)
// and each centroid (upto 32). Can store values as large as 16,777,216. Computing square roots could reduce this number of bits significantly
// at the cost of longer run times.
`define DIST_SIZE_BITS_NB (24)
`define DIST_SIZE_BITS_LB (5)

// DC DIMENSIONS: Do NOT MAKE LESS THAN 16-bits wide. Using 24-bit numbers allows the distance sums to get to 16,777,216 in size (2**24)
`define DC_BRAM_WORD_SIZE_BITS_NB (24)
`define DC_BRAM_WORD_SIZE_BITS_LB (5)

// 24*32*1024/24 = 32,768 (24-bit words)
`define DIST_LADDR (0)
`define DIST_HADDR ((`DIST_SIZE_BITS_NB * `ACTUAL_MAX_NUM_CLUSTERS_NB * `MAX_NUM_POINTS_NB)/`DC_BRAM_WORD_SIZE_BITS_NB)

// Whole region is 32,768 words in size. 15-bit address allows upto 32,768 words.
`define DC_BRAM_ADDR_SIZE_BITS_NB (15)
`define DC_BRAM_NUM_WORDS_NB (`DIST_HADDR)

`define GPIO_WORD_SIZE_BITS_NB (32)
`define GPIO_WORD_SIZE_BITS_LB (5)


//Verilog function to find square root of a 32 bit number.
//The output is 16 bit.
//function [15:0] sqrt_t;
//  input [31:0] num;  //declare input
//  //intermediate signals.
//  reg [31:0] a;
//  reg [15:0] q;
//  reg [17:0] left, right, r;
//  integer i;
//  begin
//    //initialize all the variables.
//    a = num;
//    q = 0;
//    i = 0;
//    left = 0;  //input to adder/sub
//    right = 0;  //input to adder/sub
//    r = 0;  //remainder
//    //run the calculations for 16 iterations.
//    for (i = 0; i < 16; i = i + 1) begin
//      right = {q, r[17], 1'b1};
//      left = {r[15:0], a[31:30]};
//      a = {a[29:0], 2'b00};  //left shift by 2 bits.
//      if (r[17] == 1)  //add if r is negative
//        r = left + right;
//      else  //subtract if r is positive
//        r = left - right;
//      q = {q[14:0], !r[17]};
//    end
//    assign sqrt_t = q;  //final assignment of output.
//  end
//endfunction


//function [15:0] sqr;

//  input [31:0] num;  //declare input
//  reg [31:0] sum;
//  begin
//    sum = 0;
//    for (int count = 32'hFFFFFFFF; count > 0; count = count -1) begin
//      sum = sum + num;
//    end

//   assign sqr = sum;

//  end

//endfunction
