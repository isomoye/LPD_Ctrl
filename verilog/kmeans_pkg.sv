package kmeans_pkg;

// We represent numbers in FIXED-POINT format, with 12-bit  portion of the 16-bit number stored in the PN BRAM. 
// The fractional component is given by 'PRECISION' and the sum is PN_SIZE_NB. PN_SIZE_LB needs to be able to count 
// to PN_SIZE_NB.
parameter int PN__NB   =   12;
parameter int PN_PRECISION_NB =   4;
parameter int PN_SIZE_LB      =   4;
parameter int PN_SIZE_NB      =   PN__NB + PN_PRECISION_NB;
parameter int PROG_VALS       =   3;

parameter int BYTE_SIZE_LB =   3;
parameter int BYTE_SIZE_NB =   8;

parameter int WORD_SIZE_LB =   4;
parameter int WORD_SIZE_NB =   16;

// BRAM SIZES= PNL is currently 16384 bytes with 16-bit words. 
parameter int PNL_BRAM_ADDR_SIZE_NB   =   15;
parameter int PNL_BRAM_DBITS_WIDTH_LB =   PN_SIZE_LB;
parameter int PNL_BRAM_DBITS_WIDTH_NB =   PN_SIZE_NB;
parameter int PNL_BRAM_NUM_WORDS_NB   =   2**PNL_BRAM_ADDR_SIZE_NB;

// Total number PNs loaded into region 4096 to 8192 is 2^12 = 4096.
parameter int NUM_PNS_NB =   12;
parameter int NUM_PNS    =   2**NUM_PNS_NB;
parameter int ARRAY_SIZE =   NUM_PNS / 2;

// Largest positive (signed) value for PNs is 1023.9375 which is in binary 01111111111.1111, BUT AS a  binary value with no 
// decimal place, it is 16383 (0011111111111111) (note, we have 16-bit for the word size now).
parameter int LARGEST_POS_VAL =   16383;

// My largest negative value is -1023.9375 or 110000000000.0001, AND as a  binary value, -16383
parameter int LARGEST_NEG_VAL =   -16383;

// We store the raw data in the upper half of memory (locations 4096 to 8191). 
parameter int PN_BRAM_BASE   =   24576;
parameter int PN_UPPER_LIMIT =   PNL_BRAM_NUM_WORDS_NB;

// Kmeans range
parameter int DIST_BRAM_BASE            =   10240;
//parameter int DIST_BRAM_UPPER_LIMIT     =   12288;
parameter int CLUSTER_BASE_ADDR         =   8192;
parameter int COPY_CLUSTER_BASE_ADDR    =   4096;
//parameter int CENTROIDS_BASE_ADDR       =   4096;
parameter int FINAL_CLUSTER_UPPER_LIMIT =   4096 / 2;
parameter int FINAL_CLUSTER_BASE_ADDR   =   0;

parameter int NUM_VALS_ADDR     =   0;
parameter int NUM_CLUSTERS_ADDR =   1;
parameter int NUM_DIMS_ADDR     =   2;

parameter int MAX_ITERATIONS =   100;



endpackage