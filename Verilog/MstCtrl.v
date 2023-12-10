//////////////////////////////////////////////////////////////////////////////////
// Company: University of New Mexico
// Engineer: Professor Jim Plusquellic, Copyright Univ. of New Mexico
//
// Create Date:
// Design Name:
// Module Name:    MstCtrl - Behavioral
// Project Name:
// Target Devices:
// Tool versions:
// Description:
// 
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

`include "DataTypes.vh"

module MstCtrl (
    input wire Clk,
    input wire RESET,
    input wire start,
    output wire ready,
    output reg Mst_stopped,
    input wire Mst_continue,
    input wire [`GPIO_WORD_SIZE_BITS_NB-1:0] params_in_word,
    output reg LM_ULM_IO_start,
    input wire LM_ULM_IO_ready,
    output reg LM_ULM_DC_start,
    input wire LM_ULM_DC_ready,
    output reg LM_ULM_load_unload,
    output reg LM_ULM_BRAM_select,
    output reg Mod1_start,
    input wire Mod1_ready,
    output reg [`IO_BRAM_ADDR_SIZE_BITS_NB-1:0] LM_ULM_IO_base_address,
    output reg [`IO_BRAM_ADDR_SIZE_BITS_NB-1:0] LM_ULM_IO_upper_limit,
    output reg [`DC_BRAM_ADDR_SIZE_BITS_NB-1:0] LM_ULM_DC_base_address,
    output reg [`DC_BRAM_ADDR_SIZE_BITS_NB-1:0] LM_ULM_DC_upper_limit,
    output wire [`GPIO_WORD_SIZE_BITS_NB-1:0] param1,
    output wire [`GPIO_WORD_SIZE_BITS_NB-1:0] param2,
    output wire CLUSTER_ERR,
    output wire POINT_ERR
);

  localparam MAX_PARAMS_NB = 3;
  localparam MAX_PARAMS_LB = 2;

  localparam STATE_IDLE = 4'd0,
              STATE_WAIT_START_LOW = 4'd1,
              STATE_GET_PARAMS = 4'd2,
              STATE_WAIT_PARAMS = 4'd3,
              STATE_READ_POINTS = 4'd4,
              STATE_WAIT_READ_POINTS = 4'd5,
              STATE_DUMP_POINTS = 4'd6,
              STATE_WAIT_DUMP_POINTS = 4'd7,
              STATE_DUMP_DIST = 4'd8,
              STATE_WAIT_DUMP_DIST = 4'd9,
              STATE_KMEANS_DIST_CALC = 4'd10,
              STATE_KMEANS_WAIT_DIST = 4'd11,
              STATE_KMEANS_DUMP_DIST = 5'd12,
              STATE_KMEANS_WAIT_DUMP_DIST = 5'd13              
              ;

  // Make this big enough to allow all of the above states to be represented in binary. With [3:0], we can support up to 16 states. Increase size as needed.
  reg [3:0] state_reg, state_next;
  reg ready_reg, ready_next;

  reg [MAX_PARAMS_LB-1:0] param_cnt_reg, param_cnt_next;
  reg [`GPIO_WORD_SIZE_BITS_NB-1:0] param1_reg, param1_next;
  reg [`GPIO_WORD_SIZE_BITS_NB-1:0] param2_reg, param2_next;
  reg [`GPIO_WORD_SIZE_BITS_NB-1:0] param3_reg, param3_next;

  reg CLUSTER_ERR_reg, CLUSTER_ERR_next;
  reg POINT_ERR_reg, POINT_ERR_next;

  // =============================================================================================
  // State and register logic
  // =============================================================================================
  always @(posedge Clk or posedge RESET) begin
    if (RESET == 1'b1) begin
      state_reg <= STATE_IDLE;
      ready_reg <= 1'b1;
      param_cnt_reg <= {MAX_PARAMS_LB{1'b0}};
      param1_reg <= {`GPIO_WORD_SIZE_BITS_NB{1'b0}};
      param2_reg <= {`GPIO_WORD_SIZE_BITS_NB{1'b0}};
      param3_reg <= {`GPIO_WORD_SIZE_BITS_NB{1'b0}};
      CLUSTER_ERR_reg <= 1'b0;
      POINT_ERR_reg <= 1'b0;
    end else begin
      state_reg <= state_next;
      ready_reg <= ready_next;
      param_cnt_reg <= param_cnt_next;
      param1_reg <= param1_next;
      param2_reg <= param2_next;
      param3_reg <= param3_next;
      CLUSTER_ERR_reg <= CLUSTER_ERR_next;
      POINT_ERR_reg <= POINT_ERR_next;
    end
  end

  // =============================================================================================
  // Combo logic
  // =============================================================================================
  always @(*) begin
    state_next = state_reg;
    ready_next = ready_reg;

    param_cnt_next = param_cnt_reg;

    param1_next = param1_reg;
    param2_next = param2_reg;
    param3_next = param3_reg;

    CLUSTER_ERR_next = CLUSTER_ERR_reg;
    POINT_ERR_next = POINT_ERR_reg;

    LM_ULM_IO_start = 1'b0;
    LM_ULM_DC_start = 1'b0;
    Mod1_start = 1'b0;

    LM_ULM_load_unload = 1'b0;
    LM_ULM_BRAM_select = 1'b0;

    // Setting these to the full region of memory. Override these assignment below as needed. 
    LM_ULM_IO_base_address = 0;
    LM_ULM_IO_upper_limit = `FCENTROID_HADDR - 1;
    LM_ULM_DC_base_address = 0;
    LM_ULM_DC_upper_limit = `DIST_HADDR - 1;

    Mst_stopped = 1'b0;

    case (state_reg)

      // =====================
      STATE_IDLE: begin
        ready_next = 1'b1;

        if (start == 1'b1) begin
          ready_next = 1'b0;

          param_cnt_next = {MAX_PARAMS_LB{1'b0}};
          CLUSTER_ERR_next = 1'b0;
          POINT_ERR_next = 1'b0;
          state_next = STATE_WAIT_START_LOW;
        end
      end

      // =====================
      STATE_WAIT_START_LOW: begin

        // Don't start again before the start bit is deasserted. ALSO important for really slow clock speeds because we need to assert 'start' for multiple clock cycles 
        // in the C program to guarantee it is recognized (start should be a two-way handshake and it is not!).
        if (start == 1'b0) begin
          state_next = STATE_GET_PARAMS;
        end
      end

      // =====================
      // Get the C program parameters
      STATE_GET_PARAMS: begin

        // C program is blocked waiting for 'Mst_stopped'. Once received, it puts a parameter on the incoming GPIO register. Get it and start the acknowledge sequence.
        Mst_stopped = 1'b1;
        if (Mst_continue == 1'b1) begin
          case (param_cnt_reg)
            0: param1_next = params_in_word[`GPIO_WORD_SIZE_BITS_NB-1:0];
            1: param2_next = params_in_word[`GPIO_WORD_SIZE_BITS_NB-1:0];
            default: param3_next = params_in_word[`GPIO_WORD_SIZE_BITS_NB-1:0];
          endcase

          state_next = STATE_WAIT_PARAMS;
        end
      end

      // =====================
      // C program holds 'Mst_continue' at 1 until it sees 'Mst_stopped' go to 0, at which point, it drops 'Mst_continue' to 0.
      STATE_WAIT_PARAMS: begin
        if (Mst_continue == 1'b0) begin

          // Done collecting parameters
          if (param_cnt_reg == MAX_PARAMS_NB - 1) begin
            state_next = STATE_READ_POINTS;
          end else begin
            param_cnt_next = param_cnt_reg + 1;
            state_next = STATE_GET_PARAMS;
          end
        end
      end

      // =====================
      // Read the points into IO BRAM
      STATE_READ_POINTS: begin
        if (LM_ULM_IO_ready == 1'b1) begin

          // LoadUnloadBRAM modules take snapshots of these once started. Set these to the desired region.
          LM_ULM_IO_base_address = 0;
          LM_ULM_IO_upper_limit = `FCENTROID_HADDR - 1;
          LM_ULM_IO_start = 1'b1;
          LM_ULM_load_unload = 1'b0;
          LM_ULM_BRAM_select = 1'b0;
          state_next = STATE_WAIT_READ_POINTS;
        end
      end

      // =====================
      // Read the points into IO BRAM
      STATE_WAIT_READ_POINTS: begin

        // Hold these signals at the proper value for the entire duration of the transfer operation.
        LM_ULM_load_unload = 1'b0;
        LM_ULM_BRAM_select = 1'b0;
        if (LM_ULM_IO_ready == 1'b1) begin
          state_next = STATE_DUMP_POINTS;
        end
      end

      // =====================
      // Read the points into IO BRAM
      STATE_DUMP_POINTS: begin
        if (LM_ULM_IO_ready == 1'b1) begin

          // LoadUnloadBRAM modules take snapshots of these once started. Set these to the desired region.
          LM_ULM_IO_base_address = 0;
          LM_ULM_IO_upper_limit = `FCENTROID_HADDR - 1;
          LM_ULM_IO_start = 1'b1;

          // Unload
          LM_ULM_load_unload = 1'b1;
          LM_ULM_BRAM_select = 1'b0;
          state_next = STATE_WAIT_DUMP_POINTS;
        end
      end

      // =====================
      // Wait for dump to complete
      STATE_WAIT_DUMP_POINTS: begin
        // Unload: Hold these signals at the proper value for the entire duration of the transfer operation.
        LM_ULM_load_unload = 1'b1;
        LM_ULM_BRAM_select = 1'b0;
        if (LM_ULM_IO_ready == 1'b1) begin
          state_next = STATE_DUMP_DIST;
        end
      end

      // =====================
      // Dump the DIST values in DC BRAM
      STATE_DUMP_DIST: begin
        if (LM_ULM_DC_ready == 1'b1) begin

          // LoadUnloadBRAM modules take snapshots of these once started. Set these to the desired region.
          LM_ULM_DC_base_address = 0;
          LM_ULM_DC_upper_limit = `DIST_HADDR - 1;
          LM_ULM_DC_start = 1'b1;

          // Unload
          LM_ULM_load_unload = 1'b1;
          LM_ULM_BRAM_select = 1'b1;
          state_next = STATE_WAIT_DUMP_DIST;
        end
      end

      // =====================
      // Wait for dump to complete
      STATE_WAIT_DUMP_DIST: begin

        // Unload: Hold these signals at the proper value for the entire duration of the transfer operation.
        LM_ULM_load_unload = 1'b1;
        LM_ULM_BRAM_select = 1'b1;
        if (LM_ULM_DC_ready == 1'b1) begin

          // TEMPORARY: Define a state that starts KMeans processing algorithm.
                            state_next = STATE_KMEANS_DIST_CALC;
                            LM_ULM_load_unload = 1'b0;
        LM_ULM_BRAM_select = 1'b0;
        Mod1_start = 1'b1;
                      
          //state_next = STATE_IDLE;
        end
      end
      STATE_KMEANS_DIST_CALC: begin
          state_next = STATE_KMEANS_WAIT_DIST;
      end
      STATE_KMEANS_WAIT_DIST: begin
        if(Mod1_ready) begin
          Mst_stopped = 1'b1;
          ready_next = 1'b1;
          if (Mst_continue == 1'b1) begin

          state_next = STATE_KMEANS_DUMP_DIST;
          end
        end
      end
      // =====================
      // Dump the DIST values in DC BRAM
      STATE_KMEANS_DUMP_DIST: begin
        if (LM_ULM_DC_ready == 1'b1) begin

          // LoadUnloadBRAM modules take snapshots of these once started. Set these to the desired region.
          LM_ULM_DC_base_address = 0;
          LM_ULM_DC_upper_limit = `DIST_HADDR - 1;
          LM_ULM_DC_start = 1'b1;

          // Unload
          LM_ULM_load_unload = 1'b1;
          LM_ULM_BRAM_select = 1'b1;
          state_next = STATE_KMEANS_WAIT_DUMP_DIST;
        end
      end

      // =====================
      // Wait for dump to complete
      STATE_KMEANS_WAIT_DUMP_DIST: begin

        // Unload: Hold these signals at the proper value for the entire duration of the transfer operation.
        LM_ULM_load_unload = 1'b1;
        LM_ULM_BRAM_select = 1'b1;
        if (LM_ULM_DC_ready == 1'b1) begin

          // TEMPORARY: Define a state that starts KMeans processing algorithm.
                            state_next = STATE_IDLE;
                            LM_ULM_load_unload = 1'b0;
        LM_ULM_BRAM_select = 1'b0;
                            ready_next = 1'b1;
          //state_next = STATE_IDLE;
        end
      end

      // =====================
      default: begin
        state_next = STATE_IDLE;
      end
    endcase
  end

  assign ready = ready_reg;

    assign param1 = param1_reg;
    assign param2 = param2_reg;
  //   assign param3 = param3_reg;

  assign CLUSTER_ERR = CLUSTER_ERR_reg;
  assign POINT_ERR = POINT_ERR_reg;

endmodule : MstCtrl
