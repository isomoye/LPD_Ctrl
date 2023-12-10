
// parameter int PNL_BRAM_ADDR_SIZE_NB = 15;
// parameter int PNL_BRAM_DBITS_WIDTH_NB = PN_SIZE_NB;
// parameter int PN__NB = 12;
// parameter int PN_PRECISION_NB = 4;
// parameter int PN_SIZE_LB = 4;
// parameter int PN_SIZE_NB = PN__NB + PN_PRECISION_NB;

`include "DataTypes.vh"

module CopyAssignmentArray
  import kmeans_pkg::*;
(
    input logic clk_i,
    input logic reset_i,
    //start and ready
    input logic start_i,
    input logic store_i,
    output logic ready_o,
    //io mem signals
    mem_intf io_bram_if,
    //dc mem signals
    mem_intf dc_bram_if,
    //input values if
    num_intf num_if
);

  typedef enum logic [2:0] {
    ST_IDLE,
    ST_GET_CLUSTER,
    ST_STORE_CENTROIDS
  } state_e;

  state_e curr_state;
  state_e next_state;

  logic ready_c;
  logic ready_r;

  logic start_c;
  logic start_r;

  logic [`IO_BRAM_ADDR_SIZE_BITS_NB-1:0] IO_BRAM_addr_c;
  logic [`IO_BRAM_ADDR_SIZE_BITS_NB-1:0] IO_BRAM_addr_r;

  logic [31:0] point_count_c;
  logic [31:0] point_count_r;

  logic [`IO_BRAM_WORD_SIZE_BITS_NB-1:0] cluster_prev_c[`MAX_NUM_POINTS_NB/4];
  logic [`IO_BRAM_WORD_SIZE_BITS_NB-1:0] cluster_prev_r[`MAX_NUM_POINTS_NB/4];



  always_ff @(posedge clk_i) begin : main_seq
    if (reset_i) begin
      curr_state     <= ST_IDLE;
      ready_r        <= '1;
      IO_BRAM_addr_r <= `FCLUSTER_LADDR;
      point_count_r  <= '0;
      start_r        <= '0;
    end else begin
      curr_state     <= next_state;
      ready_r        <= ready_c;
      IO_BRAM_addr_r <= IO_BRAM_addr_c;
      points_r       <= points_c;
      point_count_r  <= point_count_c;
      start_r        <= start_c;
    end

    cluster_prev_r <= cluster_prev_c;
  end




  always_comb begin : main_combo
    next_state = curr_state;
    ready_c = ready_r;

    IO_BRAM_addr_c = IO_BRAM_addr_r;
    io_bram_if.we = '0;
    io_bram_if.dout = '0;
    point_count_c = point_count_r;
    start_c = start_r;
    dc_bram_if.dout = '0;
    dc_bram_if.we = '0;

    cluster_prev_c = cluster_prev_r;

    case (curr_state)
      ST_IDLE: begin
        ready_c = '1;
        if (start_i) begin
          ready_c = '0;
          point_count_c = '0;
          next_state = ST_GET_CENTROIDS;
          IO_BRAM_addr_c = `FCLUSTER_LADDR;
          if (store_i) begin
            next_state = ST_STORE_CENTROIDS;
            io_bram_if.dout = cluster_prev_r[point_count_r];
            io_bram_if.we = '1;
          end
        end
      end
      ST_GET_CENTROIDS: begin
        point_count_c = point_count_r + 1;
        IO_BRAM_addr_c = IO_BRAM_addr_r + 1;
        cluster_prev_c[point_count_r] = io_bram_if.din;
        if ((point_count_r >= num_if.vals / 4) || (point_count_r >= MAX_NUM_POINTS_NB / 4)) begin
          next_state = ST_IDLE;
          ready_c = '1;
        end
      end
      ST_STORE_CENTROIDS: begin
        point_count_c   = point_count_r + 1;
        IO_BRAM_addr_c  = IO_BRAM_addr_r + 1;
        io_bram_if.dout = cluster_prev_r[point_count_r];
        io_bram_if.we   = '1;
        if ((point_count_r >= num_if.vals / 4) || (point_count_r >= MAX_NUM_POINTS_NB / 4)) begin
          next_state = ST_IDLE;
          ready_c = '1;
        end
      end
      default: begin
      end
    endcase
  end


  assign io_bram_if.addr = IO_BRAM_addr_c;
  assign dc_bram_if.addr = dist_count_r;
  assign ready_o = ready_r;

endmodule
