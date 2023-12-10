`include "DataTypes.vh"

module kmeans_algor
  import kmeans_pkg::*;
(
    input logic clk_i,
    input logic reset_i,

    //control signals
    input  logic start_i,
    output logic ready_o,
    output logic Kmeans_Err_o,

    //mem signals
    //PNL signals
    output logic [`IO_BRAM_ADDR_SIZE_BITS_NB-1:0] IO_BRAM_addr_o,
    output logic [`IO_BRAM_WORD_SIZE_BITS_NB-1:0] IO_BRAM_dout_o,
    input logic [`IO_BRAM_WORD_SIZE_BITS_NB-1:0] IO_BRAM_din_i,
    output logic [0:0] IO_BRAM_we_o,

    output logic [`DC_BRAM_ADDR_SIZE_BITS_NB-1:0] DC_BRAM_addr_o,
    output logic [`DC_BRAM_WORD_SIZE_BITS_NB-1:0] DC_BRAM_dout_o,
    input logic [`DC_BRAM_WORD_SIZE_BITS_NB-1:0] DC_BRAM_din_i,
    output logic [0:0] DC_BRAM_we_o,

    input logic [`GPIO_WORD_SIZE_BITS_NB - 1:0] Num_Vals_i,
    input logic [`GPIO_WORD_SIZE_BITS_NB - 1:0] Num_Clusters_i,
    input logic [`GPIO_WORD_SIZE_BITS_NB - 1:0] Num_Dims_i
);

  // Parameters
  parameter K = 3;  // Number of clusters
  parameter MAX_ITER = 100;  // Maximum iterations

  //interfaces
  //   mem_intf #(`IO_BRAM_WORD_SIZE_BITS_NB) io_mem_if ();
  //   mem_intf #(`DC_BRAM_WORD_SIZE_BITS_NB) dc_mem_if ();
  //   num_intf nums_if ();

  //   logic [`IO_BRAM_WORD_SIZE_BITS_NB-1:0] cluster_centers_c[`MAX_NUM_POINTS_NB];
  //   logic [`IO_BRAM_WORD_SIZE_BITS_NB-1:0] cluster_centers_c[`MAX_NUM_POINTS_NB];



  typedef enum logic [4:0] {
    ST_IDLE,
    ST_GET_POINTS,
    ST_GET_CENTERS,
    ST_GET_DIST,
    ST_STORE_DIST,
    ST_CALC_ALL,
    ST_WAIT_CALC_ALL,
    ST_FIND_CENT,
    ST_WAIT_DIV,
    ST_CHECK_ASSIGNS,
    ST_WAIT_FIND_CENT,
    ST_COPY,
    ST_CALC_CLUS,
    ST_CALC_TOTAL
  } state_e;

  state_e curr_state;
  state_e next_state;

  logic ready_c;
  logic ready_r;

  logic start_c;
  logic start_r;

  //counters
  logic [7:0] cluster_cnt_c;
  logic [7:0] cluster_cnt_r;
  logic [7:0] point_count_c;
  logic [7:0] point_count_r;
  logic [3:0] byte_count_c;
  logic [3:0] byte_count_r;

  logic [7:0] iter_c;
  logic [7:0] iter_r;


  points_t  points_c[`MAX_NUM_POINTS_NB];
  points_t  points_r[`MAX_NUM_POINTS_NB];


  points_t cluster_centers_c[`MAX_NUM_CLUSTERS_NB];
  points_t cluster_centers_r[`MAX_NUM_CLUSTERS_NB];

  points_t new_centers_c[`MAX_NUM_CLUSTERS_NB];
  points_t new_centers_r[`MAX_NUM_CLUSTERS_NB];

  points_t sums_c[`MAX_NUM_CLUSTERS_NB];
  points_t sums_r[`MAX_NUM_CLUSTERS_NB];

  logic [63:0] active_cluster_c;
  logic [63:0] active_cluster_r;

  logic [15:0] cluster_mem_cnt_c[`MAX_NUM_CLUSTERS_NB];
  logic [15:0] cluster_mem_cnt_r[`MAX_NUM_CLUSTERS_NB];

  logic [63:0] closest_dist_c;
  logic [63:0] closest_dist_r;
  logic [7:0] best_index_c;
  logic [7:0] best_index_r;

  logic [7:0] dist_count_r;
  logic [7:0] dist_count_c;


  logic [7:0] fraction_a;
  logic [7:0] fraction_b;

  logic converged_c;
  logic converged_r;


  pnt_fct_t  data_a;
  pnt_fct_t  data_b;
  pnt_fct_t result_a;
  pnt_fct_t result_b;
  logic ovfl_a;
  logic ovfl_b;

  pnt_fct_t div_a;
  pnt_fct_t div_b;
  logic start_div;
  logic done_div_a;
  logic done_div_b;

  logic [`IO_BRAM_ADDR_SIZE_BITS_NB:0] mult_res_a;
  logic [`IO_BRAM_ADDR_SIZE_BITS_NB:0] mult_res_b;
  assign mult_res_a = {ovfl_a, result_a};
  assign mult_res_b = {ovfl_b, result_b};
   logic [31:0] diff;
  //logic [23:0] curr_dist;


  // Internal registers
  //   logic [31:0] centers[K];
  //   logic [31:0] new_centers[K];
  //   logic [31:0] data_point;
  //   logic [31:0] distances[K];
  //   logic [31:0] min_distance;
  //   logic [2:0] nearest_cluster;
  //   logic [31:0] sum[K];
  //   logic [7:0] cluster_size[K];
  //   logic [31:0] temp_center;
  //   logic [31:0] diff;


  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      curr_state <= ST_IDLE;
      ready_r <= '1;
      iter_r <= '0;
      point_count_r   <= '0;
      cluster_cnt_r <= '0;
      dist_count_r    <= '0;
      active_cluster_r <= '0;
      converged_r <= '0;
    end else begin
      curr_state <= next_state;
      ready_r <= ready_c;
      iter_r <= iter_c;
      point_count_r   <= point_count_c;
      cluster_cnt_r <= cluster_cnt_c;
      dist_count_r    <= dist_count_c;
      active_cluster_r <= active_cluster_c;
      converged_r <= converged_c;
    end
    points_r <= points_c;
    best_index_r <= best_index_c;
    closest_dist_r <= closest_dist_c;
    byte_count_r <= byte_count_c;
    cluster_centers_r <= cluster_centers_c;
    sums_r <= sums_c;
    cluster_mem_cnt_r <= cluster_mem_cnt_c;
    new_centers_r <= new_centers_c;

  end


  always_comb begin : main_combo
    next_state = curr_state;
    ready_c = ready_r;
    IO_BRAM_addr_o  = '0;
    IO_BRAM_dout_o  = '0;
    IO_BRAM_we_o    = '0;
    DC_BRAM_addr_o  = '0;
    DC_BRAM_dout_o  = '0;
    DC_BRAM_we_o    = '0;
    fraction_a = '0;
    fraction_b = '0;
    data_a = '0;
    data_b = '0;
    // curr_dist = '0;
    point_count_c = point_count_r;
    cluster_cnt_c = cluster_cnt_r;
    dist_count_c = dist_count_r;
    points_c = points_r;
    cluster_centers_c = cluster_centers_r;
    active_cluster_c = active_cluster_r;
    best_index_c = best_index_r;
    closest_dist_c = closest_dist_r;
    byte_count_c = byte_count_r;
    sums_c = sums_r;
    cluster_mem_cnt_c = cluster_mem_cnt_r;
    new_centers_c = new_centers_r;
    converged_c = converged_r;
    iter_c = iter_r;
    start_div = '0;
    diff  = '0;
    case (curr_state)
      ST_IDLE: begin
        ready_c = '1;
        if (start_i) begin
          ready_c = '0;
          next_state = ST_GET_POINTS;
          IO_BRAM_addr_o = `POINT_LADDR;
        end
      end
      ST_GET_POINTS: begin
        //set address
        IO_BRAM_addr_o = `POINT_LADDR + point_count_r;
        //increment point count
        point_count_c = point_count_r + 1;
        //store point
        points_c[point_count_r] = IO_BRAM_din_i;
        //check if points complete
        if (point_count_r >= Num_Vals_i - 1 ||
        (point_count_r >= `MAX_NUM_POINTS_NB - 1)) begin
          //goto get centers
          next_state = ST_GET_CENTERS;
          IO_BRAM_addr_o = `FCENTROID_LADDR;
          point_count_c = '0;
          cluster_cnt_c = '0;
        end
      end
      ST_GET_CENTERS: begin
        //set address
        IO_BRAM_addr_o = `POINT_LADDR + cluster_cnt_r;
        //increment cluster count
        cluster_cnt_c = cluster_cnt_r + 1;
        //store center
        cluster_centers_c[cluster_cnt_r] = IO_BRAM_din_i;
        cluster_mem_cnt_c[cluster_cnt_r] = '0;
        new_centers_c[cluster_cnt_r] = '0;
        sums_c[cluster_cnt_r] = '0;
        //check if centers complete
        if ((cluster_cnt_r >= Num_Clusters_i)
        || (cluster_cnt_r >= `MAX_NUM_POINTS_NB)) begin
          next_state = ST_GET_DIST;
          IO_BRAM_addr_o = '0;
          point_count_c = '0;
          cluster_cnt_c = '0;
          best_index_c = '0;
          closest_dist_c = '0;
          byte_count_c = '0;
        end
      end
      ST_GET_DIST: begin
        //get distance for dim 1
          data_a = points_r[point_count_r].point_a -
          cluster_centers_r[cluster_cnt_r].point_a;
        //get distance for dim 2
          data_b = points_r[point_count_r].point_b -
          cluster_centers_r[cluster_cnt_r].point_b;
        active_cluster_c =  mult_res_a + mult_res_b;
        next_state = ST_STORE_DIST;
        IO_BRAM_addr_o = `FCLUSTER_LADDR + dist_count_r;
      end
      ST_STORE_DIST: begin
        logic [31:0] current_cluster;
        DC_BRAM_addr_o = point_count_r;
        DC_BRAM_dout_o = active_cluster_r;
        DC_BRAM_we_o = '1;
        cluster_cnt_c = cluster_cnt_r + 1;
        current_cluster = IO_BRAM_din_i;
        IO_BRAM_addr_o = `FCLUSTER_LADDR + dist_count_r;
        next_state = ST_GET_DIST;
        if ((cluster_cnt_r == '0) || (active_cluster_r < closest_dist_r)) begin
          closest_dist_c = active_cluster_r;
          best_index_c   = cluster_cnt_r;
        end
        if ((cluster_cnt_r >= Num_Clusters_i-1) || (cluster_cnt_r >= `MAX_NUM_CLUSTERS_NB-1)) begin
          cluster_cnt_c = '0;
          point_count_c = point_count_r + 1;
          byte_count_c = byte_count_r + 1;
          IO_BRAM_dout_o = current_cluster;
          current_cluster[((8*byte_count_r)-1)+:8] = best_index_c;
          sums_c[best_index_c].point_a = sums_r[best_index_c].point_a +
             points_r[point_count_r].point_a;
          sums_c[best_index_c].point_b =  sums_r[best_index_c].point_b +
          points_r[point_count_r].point_b;
          cluster_mem_cnt_c[best_index_c] = cluster_mem_cnt_r[best_index_c] + 1;
          if (byte_count_r >= 3) begin
            byte_count_c = '0;
          end
          if ((point_count_r >= Num_Vals_i - 1) || (point_count_r >= `MAX_NUM_POINTS_NB - 1)) begin
            next_state = ST_FIND_CENT;
            point_count_c = '0;
            cluster_cnt_c = '0;
          end
        end
      end
      ST_FIND_CENT: begin
        cluster_cnt_c = cluster_cnt_r + 1;
        if (cluster_mem_cnt_r[cluster_cnt_r] != '0) begin
          start_div = '1;
          next_state = ST_WAIT_DIV;
        end else begin
          new_centers_c[cluster_cnt_r] = cluster_centers_r[cluster_cnt_r];
          next_state = ST_CHECK_ASSIGNS;
        end
        if ((cluster_cnt_r >= Num_Clusters_i) ||
        (cluster_cnt_r >= `MAX_NUM_CLUSTERS_NB-1)) begin
          next_state = ST_CHECK_ASSIGNS;
          converged_c = '0;
          cluster_cnt_c = '0;
        end
      end
      ST_WAIT_DIV: begin
        if(done_div_a & done_div_b) begin
          new_centers_c[cluster_cnt_r].point_a = div_a;
          new_centers_c[cluster_cnt_r].point_b = div_b;
          next_state = ST_CHECK_ASSIGNS;
        end
      end
      ST_CHECK_ASSIGNS: begin
        cluster_cnt_c = cluster_cnt_r + 1;
        sums_c[cluster_cnt_r] = '0;
        cluster_mem_cnt_c[cluster_cnt_r] = '0;
        diff[15:0] = new_centers_r[cluster_cnt_r].point_a - cluster_centers_r[cluster_cnt_r].point_a;
        diff[31:16] = new_centers_r[cluster_cnt_r].point_b - cluster_centers_r[cluster_cnt_r].point_b;
        cluster_centers_c[cluster_cnt_r] = new_centers_r[cluster_cnt_r];
        if (diff == '0) begin
          converged_c = '1;
        end
        if ((cluster_cnt_r >= Num_Clusters_i-1) ||
        (cluster_cnt_r >= `MAX_NUM_CLUSTERS_NB-1)) begin
          next_state = ST_GET_DIST;
          best_index_c = '0;
          iter_c = iter_r + 1;
          closest_dist_c = '0;
          cluster_cnt_c = '0;
          if (((converged_r != '0) || (converged_c != '0) ||
          (iter_r >= MAX_ITER - 1)) && (iter_r != '0)) begin
            next_state = ST_COPY;
            cluster_cnt_c = '0;
          end
        end
      end
      ST_COPY: begin
        cluster_cnt_c  = cluster_cnt_r + 1;
        IO_BRAM_addr_o = `POINT_LADDR + cluster_cnt_r;
        IO_BRAM_dout_o = cluster_centers_r[cluster_cnt_r];
        IO_BRAM_we_o   = '1;
        if ((cluster_cnt_r >= Num_Clusters_i-1) ||
            (cluster_cnt_r >= `MAX_NUM_CLUSTERS_NB-1)) begin
          next_state = ST_IDLE;
        end
      end
      default: begin
      end

    endcase

  end


  qmult # (
    .Q(`COORD_SIZE_FCT_BITS_NB),
    .N(`COORD_SIZE_INT_BITS_NB)
  )
  qmult_inst_a (
    .i_multiplicand(data_a),
    .i_multiplier(data_a),
    .o_result(result_a),
    .ovr(ovfl_a)
  );


  qmult # (
    .Q(`COORD_SIZE_FCT_BITS_NB),
    .N(`COORD_SIZE_INT_BITS_NB)
  )
  qmult_inst_b (
    .i_multiplicand(data_b),
    .i_multiplier(data_b),
    .o_result(result_b),
    .ovr(ovfl_b)
  );

  qdiv # (
    .Q(4),
    .N(`IO_BRAM_WORD_SIZE_BITS_NB)
  )
  qdiv_inst_a (
    .i_dividend(sums_r[cluster_cnt_r].point_a),
    .i_divisor(cluster_mem_cnt_r[cluster_cnt_r]),
    .i_start(start_div),
    .i_clk(clk_i),
    .o_quotient_out(div_a),
    .o_complete(done_div_a),
    .o_overflow()
  );

  qdiv # (
    .Q(4),
    .N(`IO_BRAM_WORD_SIZE_BITS_NB)
  )
  qdiv_inst_b (
    .i_dividend(sums_r[cluster_cnt_r].point_b),
    .i_divisor(cluster_mem_cnt_r[cluster_cnt_r]),
    .i_start(start_div),
    .i_clk(clk_i),
    .o_quotient_out(div_b),
    .o_complete(done_div_b),
    .o_overflow()
  );

  //assignments 
  assign ready_o = ready_r;
  //   assign IO_BRAM_addr_o   = io_mem_if.addr;
  //   assign IO_BRAM_dout_o   = io_mem_if.dout;
  //   assign IO_BRAM_we_o     = io_mem_if.we;
  //   assign DC_BRAM_addr_o   = dc_mem_if.addr;
  //   assign DC_BRAM_dout_o   = dc_mem_if.dout;
  //   assign DC_BRAM_we_o     = dc_mem_if.we;

  //   assign nums_if.vals     = Num_Vals_i;
  //   assign nums_if.clusters = Num_Clusters_i;
  //   assign nums_if.dims     = Num_Dims_i;

  //   assign io_mem_if.din  = DC_BRAM_din_i;
  //   assign dc_mem_if.din  = IO_BRAM_din_i;


endmodule
