`timescale 1ns / 1ps

`include "DataTypes.vh"

module Kmeans (
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

  enum logic [4:0] {
    ST_IDLE,
    ST_CALC_ALL,
    ST_WAIT_CALC_ALL,
    ST_FIND_CENT,
    ST_WAIT_FIND_CENT,
    ST_COPY,
    ST_CALC_CLUS,
    ST_CALC_TOTAL,
    ST_CHECK_ASSIGNS
  }
      curr_state, next_state;

  logic Kmeans_Bram_sel_c;
  logic Kmeans_Bram_sel_r;

  logic Kmeans_err_c;
  logic Kmeans_err_r;

  logic CalcAll_start;
  logic CalcAll_ready;


  logic FindCentroid_start;
  logic FindCentroid_ready;


  // logic [`IO_BRAM_ADDR_SIZE_BITS_NB - 1 : 0]  CalcAll_IO_BRAM_addr;
  // logic [`IO_BRAM_WORD_SIZE_BITS_NB - 1 : 0]  CalcAll_IO_BRAM_dout;
  // logic [`IO_BRAM_WORD_SIZE_BITS_NB - 1 : 0]  CalcAll_IO_BRAM_din ;
  // logic [0:0]                             CalcAll_IO_BRAM_we  ;

  // logic [`DC_BRAM_ADDR_SIZE_BITS_NB-1:0]  CalcAll_DC_BRAM_addr;
  // logic [`DC_BRAM_WORD_SIZE_BITS_NB-1:0]  CalcAll_DC_BRAM_dout;
  // logic [`DC_BRAM_WORD_SIZE_BITS_NB-1:0]  CalcAll_DC_BRAM_din ;
  // logic [0:0]                             CalcAll_DC_BRAM_we  ;

  logic ready_r, ready_c;


  mem_intf #(`IO_BRAM_WORD_SIZE_BITS_NB) calc_all_io_mem_if ();
  mem_intf #(`DC_BRAM_WORD_SIZE_BITS_NB) calc_all_dc_mem_if ();

  mem_intf #(`IO_BRAM_WORD_SIZE_BITS_NB) find_cent_io_mem_if ();
  mem_intf #(`DC_BRAM_WORD_SIZE_BITS_NB) find_cent_dc_mem_if ();

  num_intf nums_if ();



  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      curr_state <= ST_IDLE;
      ready_r <= '1;
    end else begin
      curr_state <= next_state;
      ready_r <= ready_c;
    end
  end

  always_comb begin : main_combo
    next_state = curr_state;
    CalcAll_start = '0;
    FindCentroid_start = '0;
    ready_c = ready_r;
    case (curr_state)
      ST_IDLE: begin
        ready_c = '1;
        if (start_i) begin
          CalcAll_start = '1;
          ready_c = '0;
          next_state = ST_CALC_ALL;
        end
      end

      ST_CALC_ALL: begin
        CalcAll_start = '1;
        if (!CalcAll_ready) begin
          CalcAll_start = '0;
          next_state = ST_WAIT_CALC_ALL;
        end

      end
      ST_WAIT_CALC_ALL: begin
        if (CalcAll_ready) begin
          next_state = ST_FIND_CENT;
          FindCentroid_start = '1;
        end
      end
      ST_FIND_CENT: begin
        if (!FindCentroid_ready) begin
          FindCentroid_start = '0;
          next_state = ST_WAIT_FIND_CENT;
        end

      end
      ST_WAIT_FIND_CENT: begin
        if (FindCentroid_ready) begin
          next_state = ST_IDLE;
        end

      end
      ST_COPY: begin

      end
      ST_CALC_CLUS: begin

      end
      ST_CALC_TOTAL: begin

      end
      ST_CHECK_ASSIGNS: begin

      end
      default: begin
      end
    endcase
  end

  assign ready_o = ready_r;

  CalcAllDistances CalcAllDist_inst (
      .clk_i     (clk_i),
      .reset_i   (reset_i),
      .start_i   (CalcAll_start),
      .ready_o   (CalcAll_ready),
      .io_bram_if(calc_all_io_mem_if),
      .dc_bram_if(calc_all_dc_mem_if),
      .num_if    (nums_if)
  );


  FindClosestCentroid find_centroid_inst (
      .clk_i     (clk_i),
      .reset_i   (reset_i),
      .start_i   (FindCentroid_start),
      .ready_o   (FindCentroid_ready),
      .io_bram_if(find_cent_io_mem_if),
      .dc_bram_if(find_cent_dc_mem_if),
      .num_if    (nums_if)
  );



  assign calc_all_io_mem_if.din  = DC_BRAM_din_i;
  assign calc_all_dc_mem_if.din  = IO_BRAM_din_i;
  assign find_cent_io_mem_if.din = DC_BRAM_din_i;
  assign find_cent_dc_mem_if.din = IO_BRAM_din_i;


  assign nums_if.vals            = Num_Vals_i;
  assign nums_if.clusters        = Num_Clusters_i;
  assign nums_if.dims            = Num_Dims_i;

  always_comb begin : ram_assignments
    IO_BRAM_addr_o = '0;
    IO_BRAM_dout_o = '0;
    IO_BRAM_we_o   = '0;
    DC_BRAM_addr_o = '0;
    DC_BRAM_dout_o = '0;
    DC_BRAM_we_o   = '0;
    case (curr_state)
      ST_IDLE: begin
        IO_BRAM_addr_o = '0;
        IO_BRAM_dout_o = '0;
        IO_BRAM_we_o   = '0;
        DC_BRAM_addr_o = '0;
        DC_BRAM_dout_o = '0;
        DC_BRAM_we_o   = '0;
      end
      ST_CALC_ALL, ST_WAIT_CALC_ALL: begin
        IO_BRAM_addr_o = calc_all_io_mem_if.addr;
        IO_BRAM_dout_o = calc_all_io_mem_if.dout;
        IO_BRAM_we_o   = calc_all_io_mem_if.we;
        DC_BRAM_addr_o = calc_all_dc_mem_if.addr;
        DC_BRAM_dout_o = calc_all_dc_mem_if.dout;
        DC_BRAM_we_o   = calc_all_dc_mem_if.we;
      end
      // ST_CALC_ALL: begin

      // end
      ST_FIND_CENT, ST_WAIT_FIND_CENT: begin
        IO_BRAM_addr_o = find_cent_io_mem_if.addr;
        IO_BRAM_dout_o = find_cent_io_mem_if.dout;
        IO_BRAM_we_o   = find_cent_io_mem_if.we;
        DC_BRAM_addr_o = find_cent_dc_mem_if.addr;
        DC_BRAM_dout_o = find_cent_dc_mem_if.dout;
        DC_BRAM_we_o   = find_cent_dc_mem_if.we;
      end
      ST_COPY: begin

      end
      ST_CALC_CLUS: begin

      end
      ST_CALC_TOTAL: begin

      end
      ST_CHECK_ASSIGNS: begin

      end
      default: begin

      end
    endcase

  end

endmodule



// Initialization
initial begin
  // Initialize centers
  for (int i = 0; i < K; i++) begin
    centers[i] = initial_centers[i];
  end

  // K-means iterations
  for (int iter = 0; iter < MAX_ITER; iter++) begin
    // Reset sums and cluster sizes
    for (int i = 0; i < K; i++) begin
      sum[i] = 0;
      cluster_size[i] = 0;
    end

    // Assign data points to nearest clusters
    for (int i = 0; i < 100; i++) begin
      data_point = data_points[i];

      // Calculate distances to each cluster
      for (int j = 0; j < K; j++) begin
        distances[j] = data_point - centers[j];
      end

      // Find nearest cluster
      min_distance = distances[0];
      nearest_cluster = 0;
      for (int j = 1; j < K; j++) begin
        if (distances[j] < min_distance) begin
          min_distance = distances[j];
          nearest_cluster = j;
        end
      end

      // Update sum and cluster size for nearest cluster
      sum[nearest_cluster] += data_point;
      cluster_size[nearest_cluster]++;
    end

    // Calculate new centers
    for (int i = 0; i < K; i++) begin
      if (cluster_size[i] != 0) begin
        new_centers[i] = sum[i] / cluster_size[i];
      end else begin
        new_centers[i] = centers[i];
      end
    end

    // Check for convergence
    logic converged = 1;
    for (int i = 0; i < K; i++) begin
      diff = new_centers[i] - centers[i];
      if (diff != 0) begin
        converged = 0;
        break;
      end
    end

    // Update centers and break if converged
    for (int i = 0; i < K; i++) begin
      centers[i] = new_centers[i];
    end

    if (converged) begin
      $display("Converged after %d iterations.", iter + 1);
      break;
    end
  end

  // Assign final centers
  for (int i = 0; i < K; i++) begin
    final_centers[i] = centers[i];
  end
end