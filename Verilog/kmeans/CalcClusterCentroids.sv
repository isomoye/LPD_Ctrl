`include "DataTypes.vh"

module CalcClusterCentroids
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
    ST_GET_POINTS,
    ST_STORE_CENTROIDS,
    ST_DIVIDE_CLUSTERS,
    ST_GET_CENTROIDS
  } state_e;

  state_e curr_state;
  state_e next_state;

  logic   ready_c;
  logic   ready_r;

  logic   start_c;
  logic   start_r;

  points_t points_c, points_r;
  points_t current_centroids;

  logic [`IO_BRAM_ADDR_SIZE_BITS_NB-1:0] IO_BRAM_addr_c;
  logic [`IO_BRAM_ADDR_SIZE_BITS_NB-1:0] IO_BRAM_addr_r;

  logic [31:0] cluster_cnt_c;
  logic [31:0] cluster_cnt_r;

  logic [31:0] point_count_c;
  logic [31:0] point_count_r;

  logic [3:0] byte_count_c;
  logic [3:0] byte_count_r;

  logic [31:0] active_cluster_c;
  logic [31:0] active_cluster_r;

  logic [`IO_BRAM_WORD_SIZE_BITS_NB-1:0] cluster_mem_cnt_c[`MAX_NUM_POINTS_NB];
  logic [`IO_BRAM_WORD_SIZE_BITS_NB-1:0] cluster_mem_cnt_r[`MAX_NUM_POINTS_NB];


  logic [`IO_BRAM_WORD_SIZE_BITS_NB-1:0] cluster_centroids_c[`MAX_NUM_POINTS_NB];
  logic [`IO_BRAM_WORD_SIZE_BITS_NB-1:0] cluster_centroids_c[`MAX_NUM_POINTS_NB];


  always_ff @(posedge clk_i) begin : main_seq
    if (reset_i) begin
      curr_state       <= ST_IDLE;
      ready_r          <= '1;
      IO_BRAM_addr_r   <= `FCLUSTER_LADDR;
      point_count_r    <= '0;
      start_r          <= '0;
      active_cluster_r <= '0;
      cluster_cnt_r    <= '0;
      byte_count_r     <= '0;
      points_c         <= '0;
    end else begin
      curr_state       <= next_state;
      ready_r          <= ready_c;
      IO_BRAM_addr_r   <= IO_BRAM_addr_c;
      points_r         <= points_c;
      point_count_r    <= point_count_c;
      start_r          <= start_c;
      cluster_cnt_r    <= cluster_cnt_c;
      active_cluster_r <= active_cluster_c;
      byte_count_r     <= byte_count_c;
      points_r         <= points_c;
    end

    cluster_mem_cnt_r <= cluster_mem_cnt_c;
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

    current_centroids = '0;

    cluster_cnt_c = cluster_cnt_r;

    byte_count_c = byte_count_r;

    cluster_mem_cnt_c = cluster_mem_cnt_r;

    active_cluster_c = active_cluster_r;

    points_c = points_r;

    case (curr_state)
      ST_IDLE: begin
        ready_c = '1;
        cluster_cnt_c = '0;
        if (start_i) begin
          ready_c = '0;
          point_count_c = '0;
          next_state = ST_GET_CLUSTER;
          //set address to cluster zone
          IO_BRAM_addr_c = `FCLUSTER_LADDR + cluster_cnt_r;
        end
      end
      ST_GET_CLUSTER: begin
        //byte index and store active cluster 
        active_cluster_c = io_bram_if.din[(byte_count_r*8)+:8];
        //increment clust count for active cluster
        cluster_mem_cnt_c[active_cluster_c] = cluster_mem_cnt_r[active_cluster_c] + 1;
        //set address to points zone
        IO_BRAM_addr_c = point_count_r;
        //increment byte count
        byte_count_c = byte_count_r + 1;
        //prevent byte count overflow
        if (byte_count_r >= 3) begin
          byte_count_c  = '0;
          //incrment cluster count;
          cluster_cnt_c = cluster_cnt_r + 1;
        end
        //goto get points
        next_state = ST_GET_POINTS;
      end
      ST_GET_POINTS: begin
        //store points
        points_c = io_bram_if.din;
        //set address to points zone
        IO_BRAM_addr_c = active_cluster_r + `FCENTROID_LADDR;
        next_state = ST_STORE_CENTROIDS;
      end
      ST_STORE_CENTROIDS: begin
        //get cenctroid
        current_centroids = io_bram_if.din;
        //sum each point value in dimensions
        if (cluster_mem_cnt_r[active_cluster_r] == 32'h1) begin
          io_bram_if.dout[15:0]  = points_c[15:0];
          io_bram_if.dout[31:16] = points_c[31:16];
        end else begin
          io_bram_if.dout[15:0]  = current_centroids[15:0] + points_c[15:0];
          io_bram_if.dout[31:16] = current_centroids[31:16] + points_c[31:16];
        end
        //store centroid
        IO_BRAM_addr_c = active_cluster_r + `FCENTROID_LADDR;
        io_bram_if.we  = '1;
        point_count_c  = point_count_r + 1;
        if (point_count_r >= num_if.vals) begin
          next_state = ST_DIVIDE_CLUSTERS;
          IO_BRAM_addr_c = `FCENTROID_LADDR;
          cluster_cnt_c = '0;
        end else begin
          next_state = ST_GET_CLUSTER;
          IO_BRAM_addr_c = `FCLUSTER_LADDR + cluster_cnt_r;
        end
      end
      ST_DIVIDE_CLUSTERS: begin
        //get cenctroid
        current_centroids = io_bram_if.din;
        IO_BRAM_addr_c = `FCENTROID_LADDR + cluster_cnt_r;
        cluster_cnt_c = cluster_cnt_r + 1;
        io_bram_if.we = '1;
        io_bram_if.dout[15:0] = current_centroids[15:0] / cluster_mem_cnt_r[cluster_cnt_r];
        io_bram_if.dout[31:16] = current_centroids[31:16] / cluster_mem_cnt_r[cluster_cnt_r];

        if(cluster_cnt_r >= num_if.clusters) begin
            ready_c = '1;
            next_state = ST_IDLE;
        end
        else begin
            next_state = ST_GET_CENTROIDS=[[\,./,mikknuiikik ki  ik\]]
        end
      end
      ST_GET_CENTROIDS: begin

      end
      default: begin
      end
    endcase
  end


  assign io_bram_if.addr = IO_BRAM_addr_c;
  assign dc_bram_if.addr = dist_count_r;
  assign ready_o = ready_r;

endmodule

\|\\











































|
]