`timescale 1ns / 1ps

`include "DataTypes.vh"

module FindClosestCentroid
  import kmeans_pkg::*;
(
    input logic clk_i,
    input logic reset_i,
    //start and ready
    input logic start_i,
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
    ST_GET_POINT
  } state_e;

  state_e curr_state, next_state;


  logic ready_c;
  logic ready_r;

  logic start_c, start_r;

  logic [`IO_BRAM_ADDR_SIZE_BITS_NB-1:0] IO_BRAM_addr_c, IO_BRAM_addr_r;
  points_t points_c, points_r;

  points_t [`MAX_NUM_CLUSTERS_NB-1:0] centroids_c, centroids_r;

  logic [31:0] point_count_c, point_count_r;
  logic [31:0] cluster_count_c, cluster_count_r;

  logic [31:0] dist_count_c, dist_count_r;
  logic [15:0] fraction_a, fraction_b;
  logic [15:0] data_a, data_b;

  logic [31:0] curr_dist_c, curr_dist_r;
  logic [31:0] closest_dist_c, closest_dist_r;
  logic [31:0] best_index_c, best_index_r;


  logic [31:0] cluster_addr;
  logic [31:0] cluster_data;




  always_ff @(posedge clk_i) begin : main_seq
    if (reset_i) begin
      curr_state      <= ST_IDLE;
      ready_r         <= '1;
      IO_BRAM_addr_r  <= `FCENTROID_LADDR;
      points_r        <= '0;
      centroids_r     <= '0;
      point_count_r   <= '0;
      start_r         <= '0;
      cluster_count_r <= '0;
      dist_count_r    <= '0;
      curr_dist_r     <= '0;
      closest_dist_r  <= '0;
      best_index_r    <= '0;
    end else begin
      curr_state      <= next_state;
      ready_r         <= ready_c;
      IO_BRAM_addr_r  <= IO_BRAM_addr_c;
      points_r        <= points_c;
      point_count_r   <= point_count_c;
      start_r         <= start_c;
      centroids_r     <= centroids_c;
      cluster_count_r <= cluster_count_c;
      dist_count_r    <= dist_count_c;
      curr_dist_r     <= curr_dist_c;
      closest_dist_r  <= closest_dist_c;
      best_index_r    <= best_index_c;
    end
  end



  always_comb begin : main_combo
    next_state = curr_state;
    ready_c = ready_r;

    IO_BRAM_addr_c = IO_BRAM_addr_r;
    io_bram_if.we = '0;
    io_bram_if.dout = '0;
    points_c = points_r;
    point_count_c = point_count_r;
    start_c = start_r;
    centroids_c = centroids_r;
    cluster_count_c = cluster_count_r;

    curr_dist_c = curr_dist_r;
    closest_dist_c = closest_dist_r;

    dist_count_c = dist_count_r;

    fraction_a = '0;
    fraction_b = '0;

    data_a = '0;
    data_b = '0;
    cluster_addr = '0;

    // DC_BRAM_addr_o = '0;
    dc_bram_if.dout = '0;
    dc_bram_if.we = '0;

    cluster_data = '0;

    io_bram_if.addr = '0;

    dc_bram_if.addr = '0;

    best_index_c = best_index_r;

    case (curr_state)
      ST_IDLE: begin
        ready_c = '1;
        if (start_i) begin
          ready_c = '0;
          next_state = ST_GET_POINT;
          dc_bram_if.addr = (dist_count_r * num_if.clusters) + cluster_count_r;
        end
      end
      ST_GET_POINT: begin
        curr_dist_c = dc_bram_if.din;
        cluster_count_c = cluster_count_r + 1;
        next_state = ST_GET_CLUST_ADDR;
        dc_bram_if.addr = (point_count_r * num_if.clusters) + cluster_count_r;


        cluster_addr = `FCLUSTER_LADDR + point_count_r;
        io_bram_if.addr = cluster_addr;


        if (cluster_count_r == '0 || (curr_dist_c < closest_dist_r)) begin
          best_index_c   = cluster_count_r;
          closest_dist_c = curr_dist_c;
        end

        if (cluster_count_r >= num_if.clusters) begin
          cluster_count_c = '0;
          point_count_c = point_count_r + 1;
          dist_count_c = dist_count_r + 1;

          io_bram_if.we = '1;

          cluster_data = io_bram_if.din;
          cluster_data[(dist_count_r*8)+:8] = best_index_c;
          io_bram_if.dout = cluster_data;


          if (dist_count_r >= 3) begin
            dist_count_c = '0;
          end
          if (point_count_r >= num_if.vals) begin
            next_state = ST_IDLE;
            point_count_c = '0;
            ready_c = '1;
          end

        end
      end
      default: begin
      end
    endcase

  end







  // assign io_bram_if.addr = IO_BRAM_addr_c;
  //assign dc_bram_if.addr = dist_count_r;
  assign ready_o = ready_r;



endmodule
