//////////////////////////////////////////////////////////////////////////////////
// Company: University of New Mexico
// Engineer: Professor Jim Plusquellic, Copyright Univ. of New Mexico
// 
// Create Date:
// Design Name: 
// Module Name:    LoadUnLoadMem - Behavioral 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
// LoadUnLoadMem simply transfers data into or out of IO BRAM to the GPIO register
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

module LoadUnLoadIOMem (
    input wire Clk,
    input wire RESET,
    input wire start,

    output wire ready,
    input  wire load_unload,
    output reg  stopped,

    // Previously named 'continue' but that's a (System) Verilog keyword
    input wire cont,
    input wire done,

    input wire [`IO_BRAM_ADDR_SIZE_BITS_NB-1:0] base_address,
    input wire [`IO_BRAM_ADDR_SIZE_BITS_NB-1:0] upper_limit,
    input wire [`GPIO_WORD_SIZE_BITS_NB-1:0] GPIO_in_word,
    output reg [`GPIO_WORD_SIZE_BITS_NB-1:0] GPIO_out_word,
    output wire [`IO_BRAM_ADDR_SIZE_BITS_NB-1:0] BRAM_addr,
    output reg [`IO_BRAM_WORD_SIZE_BITS_NB-1:0] BRAM_dout,
    input wire [`IO_BRAM_WORD_SIZE_BITS_NB-1:0] BRAM_din,
    output reg BRAM_we
);

  localparam IDLE = 3'd0,
              LOAD_MEM = 3'd1,
              UNLOAD_MEM = 3'd2,
              WAIT_LOAD_UNLOAD = 3'd3,
              WAIT_DONE = 3'd4;

  reg [2:0] state_reg, state_next;

  reg ready_reg, ready_next;

  reg [`IO_BRAM_ADDR_SIZE_BITS_NB-1:0] BRAM_addr_reg, BRAM_addr_next;
  reg [`IO_BRAM_ADDR_SIZE_BITS_NB-1:0] BRAM_upper_limit_reg, BRAM_upper_limit_next;

  // =============================================================================================
  // State and register logic
  // =============================================================================================
  always @(posedge Clk or posedge RESET) begin
    if (RESET == 1'b1) begin
      state_reg <= IDLE;
      ready_reg <= 1'b1;
      BRAM_addr_reg <= 0;
      BRAM_upper_limit_reg <= 0;
    end else begin
      state_reg <= state_next;
      ready_reg <= ready_next;
      BRAM_addr_reg <= BRAM_addr_next;
      BRAM_upper_limit_reg <= BRAM_upper_limit_next;
    end
  end

  // =============================================================================================
  // Combo logic
  // =============================================================================================
  always @(*) begin
    state_next = state_reg;
    ready_next = ready_reg;

    BRAM_addr_next = BRAM_addr_reg;
    BRAM_upper_limit_next = BRAM_upper_limit_reg;

    BRAM_we = 1'b0;
    BRAM_dout = 0;
    GPIO_out_word = 0;

    stopped = 1'b0;

    case (state_reg)

      // =====================
      IDLE: begin
        ready_next = 1'b1;

        if (start == 1'b1) begin
          ready_next = 1'b0;

          // Latch the 'base_address' at the instant 'start' is asserted. NOTE: 'base_address' WILL BE SET BACK TO all 0's after the 'start' signal is received.
          BRAM_addr_next = base_address;
          BRAM_upper_limit_next = upper_limit;

          if (load_unload == 1'b0) begin
            state_next = LOAD_MEM;
          end else begin
            state_next = UNLOAD_MEM;
          end
        end
      end

      // =====================
      // Write value to memory location
      LOAD_MEM: begin

        // Signal C program that we are ready to receive a word. Once ready ('cont' becomes 1'b1), transfer and complete handshake.
        stopped = 1'b1;
        if (cont == 1'b1) begin
          BRAM_we = 1'b1;

          //pad upper bits with zeroes, data in lower
          BRAM_dout = GPIO_in_word;

          // Wait for handshake signals
          state_next = WAIT_LOAD_UNLOAD;
        end

        // Handle case where C program has NOTHING to store. In this case, it asserts 'done' on what would have been the first transfer.
        if (done == 1'b1) begin
          state_next = WAIT_DONE;
        end
      end

      // =====================
      // Get value at memory location
      UNLOAD_MEM: begin

        // Put the BRAM word on GPIO_out_word. 
        GPIO_out_word = BRAM_din;

        // Signal C program that we are ready to deliver a word. Once it reads the word, 'cont' is set to 1'b1.
        stopped = 1'b1;

        // Wait handshake signals
        if (cont == 1'b1) begin
          state_next = WAIT_LOAD_UNLOAD;
        end

        // Handle case where C program does NOT need anything. In this case, it asserts 'done' on what would have been the first read.
        if (done == 1'b1) begin
          state_next = WAIT_DONE;
        end
      end

      // =====================
      // Complete handshake and update addresses
      WAIT_LOAD_UNLOAD: begin

        // C program holds 'cont' at 1 until it sees 'stopped' go to 0, and then it writes a 1'b0 to cont. It also writes 'done' with a 1'b1 when last transfer is made.
        if (cont == 1'b0) begin

          // Done collecting C program transmitted words. Force a finish if the upper limit has been reached. This will protect the memory from overruns (reading or writing). 
          if ((done == 1'b1) || (BRAM_addr_reg == BRAM_upper_limit_reg)) begin
            state_next = WAIT_DONE;
          end else begin
            BRAM_addr_next = BRAM_addr_reg + 1;
            if (load_unload == 1'b0) begin
              state_next = LOAD_MEM;
            end else begin
              state_next = UNLOAD_MEM;
            end
          end
        end
      end

      // Wait for 'done' to return to 0 before returning to IDLE. May create a race condition otherwise. If C program cannot reset 'done' to 1'b0 fast enough,
      // the next load or unload may see it high and return to IDLE (with the short-cuts, i.e., zero transfers, added above).
      WAIT_DONE: begin
        if (done == 1'b0) begin
          state_next = IDLE;
        end
      end

      // =====================
      default: begin
        state_next = IDLE;
      end
    endcase
  end

  // '_next' is probably optional here.
  assign BRAM_addr = BRAM_addr_next;
  assign ready = ready_reg;

endmodule
