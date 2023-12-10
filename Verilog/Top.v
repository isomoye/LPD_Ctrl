//--------------------------------------------------------------------------------
// Company: University of New Mexico
// Engineer: Professor Jim Plusquellic, Copyright Univ. of New Mexico
//
// Create Date:
// Design Name:
// Module Name:    Top - Behavioral
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
`timescale 1ns / 1ps

`include "DataTypes.vh"

module Top (
    input  wire Clk,
    input  wire ResetN,
    input wire [31:0] Ctrl_GPIO_Ins,
    output reg [31:0] Ctrl_GPIO_Outs,
    input wire [31:0] Data_GPIO_Ins,
    output reg [31:0] Data_GPIO_Outs,

    output reg [`IO_BRAM_ADDR_SIZE_BITS_NB-1:0] IO_BRAM_addr,
    output reg [`IO_BRAM_WORD_SIZE_BITS_NB-1:0] IO_BRAM_dout,
    input  wire [`IO_BRAM_WORD_SIZE_BITS_NB-1:0] IO_BRAM_din,
    output reg [0:0] IO_BRAM_we,

    output reg [`DC_BRAM_ADDR_SIZE_BITS_NB-1:0] DC_BRAM_addr,
    output reg [`DC_BRAM_WORD_SIZE_BITS_NB-1:0] DC_BRAM_dout,
    input  wire [`DC_BRAM_WORD_SIZE_BITS_NB-1:0] DC_BRAM_din,
    output reg [0:0] DC_BRAM_we,

    output wire DEBUG
  );

  // GPIO INPUT BIT ASSIGNMENTS
  localparam IN_RESET = 31;
  localparam IN_START = 30;
  localparam IN_MST_HANDSHAKE = 28;
  localparam IN_LM_ULM_DONE = 25;
  localparam IN_HANDSHAKE = 24;

  // GPIO OUTPUT BIT ASSIGNMENTS
  localparam OUT_READY = 31;
  localparam OUT_MST_HANDSHAKE = 29;
  localparam OUT_HANDSHAKE = 28;

  // Global signals
  wire RESET;

  wire Top_start;
  wire Top_ready;

  wire Mst_stopped;
  wire Mst_continue;

  wire LM_ULM_BRAM_select;
  //   wire LM_ULM_start, LM_ULM_ready;
  wire LM_ULM_stopped, LM_ULM_continue;
  wire LM_ULM_done;
  wire LM_ULM_load_unload;

  wire LM_ULM_IO_start, LM_ULM_IO_ready;
  wire LM_ULM_IO_stopped, LM_ULM_IO_continue;
  wire LM_ULM_IO_done;

  wire LM_ULM_DC_start, LM_ULM_DC_ready;
  wire LM_ULM_DC_stopped, LM_ULM_DC_continue;
  wire LM_ULM_DC_done;

  wire [`IO_BRAM_ADDR_SIZE_BITS_NB-1:0]LM_ULM_IO_base_address;
  wire [`IO_BRAM_ADDR_SIZE_BITS_NB-1:0]LM_ULM_IO_upper_limit;
  wire LM_ULM_IO_load_unload;
  wire [`GPIO_WORD_SIZE_BITS_NB-1:0]LM_ULM_IO_out_word;

  wire [`DC_BRAM_ADDR_SIZE_BITS_NB-1:0]LM_ULM_DC_base_address;
  wire [`DC_BRAM_ADDR_SIZE_BITS_NB-1:0]LM_ULM_DC_upper_limit;
  wire LM_ULM_DC_load_unload;
  wire [`GPIO_WORD_SIZE_BITS_NB-1:0]LM_ULM_DC_out_word;

  wire [`GPIO_WORD_SIZE_BITS_NB-1:0]LM_ULM_out_word;

  wire [  `IO_BRAM_ADDR_SIZE_BITS_NB - 1 : 0]  Load_IO_BRAM_addr;
  wire [`IO_BRAM_WORD_SIZE_BITS_NB - 1 : 0]    Load_IO_BRAM_dout;
  reg [`IO_BRAM_WORD_SIZE_BITS_NB - 1 : 0]    Load_IO_BRAM_din ;
  wire [0:0]                                   Load_IO_BRAM_we  ;

  wire [`DC_BRAM_ADDR_SIZE_BITS_NB-1:0]  Load_DC_BRAM_addr;
  wire [`DC_BRAM_WORD_SIZE_BITS_NB-1:0]  Load_DC_BRAM_dout;
  reg [`DC_BRAM_WORD_SIZE_BITS_NB-1:0]  Load_DC_BRAM_din ;
  wire [0:0]                             Load_DC_BRAM_we  ;


  wire [  `IO_BRAM_ADDR_SIZE_BITS_NB - 1 : 0]  Kmeans_IO_BRAM_addr;
  wire [`IO_BRAM_WORD_SIZE_BITS_NB - 1 : 0]    Kmeans_IO_BRAM_dout;
  reg [`IO_BRAM_WORD_SIZE_BITS_NB - 1 : 0]    Kmeans_IO_BRAM_din ;
  wire [0:0]                                   Kmeans_IO_BRAM_we  ;

  wire [`DC_BRAM_ADDR_SIZE_BITS_NB-1:0]  Kmeans_DC_BRAM_addr;
  wire [`DC_BRAM_WORD_SIZE_BITS_NB-1:0]  Kmeans_DC_BRAM_dout;
  reg [`DC_BRAM_WORD_SIZE_BITS_NB-1:0]  Kmeans_DC_BRAM_din ;
  wire [0:0]                             Kmeans_DC_BRAM_we  ;

  wire [`GPIO_WORD_SIZE_BITS_NB-1:0] param1;
  wire [`GPIO_WORD_SIZE_BITS_NB-1:0] param2;

  // Set to whatever name you want.
  wire Mod1_start;
  wire Mod1_ready;

  // =======================================================================================================
  // =======================================================================================================
  // =======================================================================================================
  // GPIO INS
  // ========
  // Software (C code) plus hardware global reset
  assign RESET = Ctrl_GPIO_Ins[IN_RESET] | !ResetN;
  assign DEBUG = RESET;

  // Start the MstCtrl state machine from the C program.
  assign Top_start = Ctrl_GPIO_Ins[IN_START];

  // Mst handshake from C program.
  assign Mst_continue = Ctrl_GPIO_Ins[IN_MST_HANDSHAKE];

  // BRAM handshake from C program.
  assign LM_ULM_continue = Ctrl_GPIO_Ins[IN_HANDSHAKE];

  // Completion signal FROM C program to one of the BRAM controllers, indicating that we are done.
  assign LM_ULM_done = Ctrl_GPIO_Ins[IN_LM_ULM_DONE];


  // GPIO OUTS
  // =========
  always @(*)
  begin
    Ctrl_GPIO_Outs[OUT_READY] = Top_ready;

    // Mst handshake to C program.
    Ctrl_GPIO_Outs[OUT_MST_HANDSHAKE] = Mst_stopped;

    // BRAM handshake to C program.
    Ctrl_GPIO_Outs[OUT_HANDSHAKE] = LM_ULM_stopped;

    // Data coming out of BRAM going to the C program
    Data_GPIO_Outs = LM_ULM_out_word;
  end

  // =====================
  // Modules
  LoadUnLoadIOMem
    LoadUnLoadIOMemMod (
      .Clk(Clk),
      .RESET(RESET),
      .start(LM_ULM_IO_start),
      .ready(LM_ULM_IO_ready),
      .load_unload(LM_ULM_load_unload),
      .stopped(LM_ULM_IO_stopped),
      .cont(LM_ULM_IO_continue),
      .done(LM_ULM_IO_done),
      .base_address(LM_ULM_IO_base_address),
      .upper_limit(LM_ULM_IO_upper_limit),
      .GPIO_in_word(Data_GPIO_Ins),
      .GPIO_out_word(LM_ULM_IO_out_word),
      .BRAM_addr(Load_IO_BRAM_addr),
      .BRAM_dout(Load_IO_BRAM_dout),
      .BRAM_din( Load_IO_BRAM_din),
      .BRAM_we(  Load_IO_BRAM_we)
    );

  LoadUnLoadDCMem
    LoadUnLoadDCMemMod (
      .Clk(Clk),
      .RESET(RESET),
      .start(LM_ULM_DC_start),
      .ready(LM_ULM_DC_ready),
      .load_unload(LM_ULM_load_unload),
      .stopped(LM_ULM_DC_stopped),
      .cont(LM_ULM_DC_continue),
      .done(LM_ULM_DC_done),
      .base_address(LM_ULM_DC_base_address),
      .upper_limit(LM_ULM_DC_upper_limit),
      .GPIO_in_word(Data_GPIO_Ins),
      .GPIO_out_word(LM_ULM_DC_out_word),
      .BRAM_addr(Load_DC_BRAM_addr),
      .BRAM_dout(Load_DC_BRAM_dout),
      .BRAM_din( Load_DC_BRAM_din),
      .BRAM_we(  Load_DC_BRAM_we)
    );

  assign LM_ULM_stopped = (LM_ULM_BRAM_select == 1'b0) ? LM_ULM_IO_stopped : LM_ULM_DC_stopped;

  assign LM_ULM_IO_continue = (LM_ULM_BRAM_select == 1'b0) ? LM_ULM_continue : 1'b0;
  assign LM_ULM_DC_continue = (LM_ULM_BRAM_select == 1'b1) ? LM_ULM_continue : 1'b0;

  assign LM_ULM_IO_done = (LM_ULM_BRAM_select == 1'b0) ? LM_ULM_done : 1'b0;
  assign LM_ULM_DC_done = (LM_ULM_BRAM_select == 1'b1) ? LM_ULM_done : 1'b0;

  assign LM_ULM_out_word = (LM_ULM_BRAM_select == 1'b0) ? LM_ULM_IO_out_word : LM_ULM_DC_out_word;

  MstCtrl
    MstCtrlMod (
      .Clk(Clk),
      .RESET(RESET),
      .start(Top_start),
      .ready(Top_ready),
      .Mst_stopped(Mst_stopped),
      .Mst_continue(Mst_continue),
      .params_in_word(Data_GPIO_Ins),
      .LM_ULM_IO_start(LM_ULM_IO_start),
      .LM_ULM_IO_ready(LM_ULM_IO_ready),
      .LM_ULM_DC_start(LM_ULM_DC_start),
      .LM_ULM_DC_ready(LM_ULM_DC_ready),
      .LM_ULM_load_unload(LM_ULM_load_unload),
      .LM_ULM_BRAM_select(LM_ULM_BRAM_select),
      .Mod1_start(Mod1_start),
      .Mod1_ready(Mod1_ready),
      .LM_ULM_IO_base_address(LM_ULM_IO_base_address),
      .LM_ULM_IO_upper_limit(LM_ULM_IO_upper_limit),
      .LM_ULM_DC_base_address(LM_ULM_DC_base_address),
      .LM_ULM_DC_upper_limit(LM_ULM_DC_upper_limit),
      .param1(param1),
      .param2(param2),
      .CLUSTER_ERR(),
      .POINT_ERR()
    );

    kmeans_algor KmeansMod(
      .clk_i           (Clk),
      .reset_i         (RESET),
      .start_i         (Mod1_start),
      .ready_o         (Mod1_ready),
      .Kmeans_Err_o     (),
      .IO_BRAM_addr_o  (Kmeans_IO_BRAM_addr),
      .IO_BRAM_din_i   (Kmeans_IO_BRAM_din),
      .IO_BRAM_dout_o  (Kmeans_IO_BRAM_dout),
      .IO_BRAM_we_o    (Kmeans_IO_BRAM_we  ),
      .DC_BRAM_addr_o  (Kmeans_DC_BRAM_addr), 
      .DC_BRAM_dout_o  (Kmeans_DC_BRAM_dout), 
      .DC_BRAM_din_i   (Kmeans_DC_BRAM_din ),
      .DC_BRAM_we_o    (Kmeans_DC_BRAM_we  ),
      .Num_Vals_i      (param1),
      .Num_Clusters_i  (param2),
      .Num_Dims_i      (32'b0)


    );

    always @(*) begin: ram_assignments
      IO_BRAM_addr = 32'b0;
      IO_BRAM_dout = 32'b0;
      IO_BRAM_we      = 32'b0;
      DC_BRAM_addr    = 32'b0;
      DC_BRAM_dout    = 32'b0;
      DC_BRAM_we      = 32'b0;
  
      Load_DC_BRAM_din = DC_BRAM_din;
      Load_IO_BRAM_din = IO_BRAM_din;

      Kmeans_DC_BRAM_din = DC_BRAM_din;
      Kmeans_IO_BRAM_din = IO_BRAM_din;

     if(Mod1_start || ~Mod1_ready) begin
        IO_BRAM_addr    = Kmeans_IO_BRAM_addr  ;
        IO_BRAM_dout    = Kmeans_IO_BRAM_dout  ;
        IO_BRAM_we      = Kmeans_IO_BRAM_we    ;
        DC_BRAM_addr    = Kmeans_DC_BRAM_addr  ;
        DC_BRAM_dout    = Kmeans_DC_BRAM_dout  ;
        DC_BRAM_we      = Kmeans_DC_BRAM_we    ;
      end
      else begin
        IO_BRAM_addr    = Load_IO_BRAM_addr;
        IO_BRAM_dout    = Load_IO_BRAM_dout;
        IO_BRAM_we      = Load_IO_BRAM_we    ;
        DC_BRAM_addr    = Load_DC_BRAM_addr   ;
        DC_BRAM_dout    = Load_DC_BRAM_dout   ;
        DC_BRAM_we      = Load_DC_BRAM_we  ;
      end
    end

endmodule
