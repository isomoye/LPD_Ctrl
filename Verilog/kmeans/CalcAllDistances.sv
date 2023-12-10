`timescale 1ns / 1ps

`include "DataTypes.vh"

module CalcAllDistances
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
    ST_GET_POINTS,
    ST_GET_CENTROIDS,
    ST_STORE_DIST,
    ST_GET_DIST,
    ST_CLUSTER_ADDR,
    ST_GET_CLUSTER,
    ST_ASSIGN_CLUSTER
  } state_e;

  state_e curr_state, next_state;

  logic ready_c;
  logic ready_r;

  logic start_c, start_r;

  logic [`IO_BRAM_ADDR_SIZE_BITS_NB-1:0] IO_BRAM_addr_c, IO_BRAM_addr_r;
  points                                                                                                              AA_t points_c, points_r;
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
  points_t cluster_data;



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

    best_index_c = best_index_r;

    case (curr_state)
      ST_IDLE: begin
        ready_c = '1;
        if (start_i) begin
          ready_c = '0;
          next_state = ST_GET_CENTROIDS;
        end
      end

      ST_GET_CENTROIDS: begin
        cluster_count_c = cluster_count_r + 1;
        IO_BRAM_addr_c = IO_BRAM_addr_r + 1;
        centroids_c[cluster_count_r] = io_bram_if.din;
        if (cluster_count_r >= num_if.clusters) begin
          next_state = ST_GET_POINTS;
          IO_BRAM_addr_c = `POINT_LADDR;
          cluster_count_c = '0;
          dist_count_c = '0;
          start_c = '1;
        end
      end

      ST_GET_POINTS: begin
        points_c = io_bram_if.din;
        point_count_c = point_count_r + 1;
        //IO_BRAM_addr_c = '0;
        best_index_c = '1;
        next_state = ST_GET_DIST;
        if (point_count_r >= num_if.vals) begin
          next_state = ST_IDLE;
          IO_BRAM_addr_c = `POINT_LADDR;
          point_count_c = '0;
          cluster_count_c = '0;
          start_c = '1;
        end
      end

      ST_GET_DIST: begin
        cluster_data = centroids_r[cluster_count_r];
        fraction_a   = (points_r.fct_b - cluster_data.fct_b);
        fraction_b   = (points_r.fct_a - cluster_data.fct_a);

        if (points_r.fct_b > cluster_data.fct_b) begin
          data_a = {(points_r.int_b - cluster_data.int_b), fraction_a};
        end else begin
          data_a = {((points_r.int_b - 1) - cluster_data.int_b), fraction_a};
        end


        if (points_r.fct_a > cluster_data.fct_a) begin
          data_b = {(points_r.int_a - cluster_data.int_a), fraction_b};
        end else begin
          data_b = {((points_r.int_a - 1) - cluster_data.int_a), fraction_b};
        end
        IO_BRAM_addr_c = point_count_r;
        curr_dist_c = (data_a * data_a) + (data_b * data_b);
        next_state = ST_STORE_DIST;
        if ((cluster_count_r >= num_if.clusters)) begin
          next_state = ST_GET_POINTS;
          cluster_count_c = '0;
        end
      end

      ST_STORE_DIST: begin
        cluster_count_c = cluster_count_r + 1;
        dist_count_c = dist_count_r + 1;
        dc_bram_if.we = '1;
        dc_bram_if.dout = curr_dist_r;
        next_state = ST_GET_POINTS;
        if ((cluster_count_r == '0) || (curr_dist_r < closest_dist_r)) begin
          closest_dist_c = curr_dist_r;
          best_index_c   = cluster_count_r;
        end

      end

      ST_GET_CLUSTER: begin
        points_c   = io_bram_if.din;
        next_state = ST_ASSIGN_CLUSTER;
      end

      ST_ASSIGN_CLUSTER: begin
        next_state = ST_GET_POINTS;
        cluster_addr = `FCLUSTER_LADDR + point_count_r;
        IO_BRAM_addr_c = {cluster_addr[31:2], 2'b0};
        io_bram_if.we = '1;

        cluster_data = points_r;
        cluster_data[(point_count_r%4)+:8] = best_index_r;
        io_bram_if.dout = cluster_data;
      end

      default: begin
      end
    endcase
  end


  assign io_bram_if.addr = IO_BRAM_addr_c;
  assign dc_bram_if.addr = dist_count_r;
  assign ready_o = ready_r;

endmodule


.model sky130_fd_pr__nfet_01v8                       
.model sky130_fd_pr__nfet_01v8
.model sky130_fd_pr__special_nfet_latch              
.model sky130_fd_pr__special_nfet_pass               
.model sky130_fd_pr__nfet_01v8_lvt
.model sky130_fd_bs_flash__special_sonosfet_star     
.model sky130_fd_pr__pfet_01v8	pfet		
.model sky130_fd_pr__pfet_01v8	scpfet	             
.model sky130_fd_pr__special_pfet_latch ppu          
.model sky130_fd_pr__pfet_01v8_lvt                   
.model sky130_fd_pr__pfet_01v8_mvt                   
.model sky130_fd_pr__pfet_01v8_hvt                   
.model sky130_fd_pr__nfet_03v3_nvt                   
.model sky130_fd_pr__pfet_g5v0d10v5                   
.model sky130_fd_pr__nfet_g5v0d10v5                   
.model sky130_fd_pr__nfet_01v8_nvt                   
.model sky130_fd_pr__diode_pw2nd_05v5 ndiode	                             
.model sky130_fd_pr__diode_pw2nd_05v5_lvt                   
.model sky130_fd_pr__diode_pw2nd_05v5_nvt                   
.model sky130_fd_pr__diode_pw2nd_11v0                    
.model sky130_fd_pr__diode_pd2nw_05v5                    
.model sky130_fd_pr__diode_pd2nw_05v5_lvt                   
.model sky130_fd_pr__diode_pd2nw_05v5_hvt                   
.model sky130_fd_pr__diode_pd2nw_11v0  
.model sky130_fd_pr__npn_05v5	pbase	                  
.model sky130_fd_pr__npn_11v0	pbase	                      
.model sky130_fd_pr__pnp_05v5	nbase	                      
.model sky130_fd_pr__cap_mim_m3_1	mimcap	                    
.model sky130_fd_pr__cap_mim_m3_2	mimcap2	                   
.model sky130_fd_pr__res_generic_nd	rdn		                   
.model sky130_fd_pr__res_generic_nd__hv                    
.model sky130_fd_pr__res_generic_pd	rdp	                   
.model sky130_fd_pr__res_generic_pd__nv                    
.model sky130_fd_pr__res_generic_l1	rli	                   
.model sky130_fd_pr__res_generic_po	npres		                   
.model sky130_fd_pr__res_high_po_*	ppres                    
.model sky130_fd_pr__res_xhigh_po_*	xres                            
.model sky130_fd_pr__cap_var_lvt	varactor	                      
.model sky130_fd_pr__cap_var_hvt	varactorhvt	                       
.model sky130_fd_pr__cap_var		mvvaractor	                        
.model sky130_fd_pr__res_iso_pw	rpw		                                
.model sky130_fd_pr__esd_nfet_g5v0d10v5                                  
.model sky130_fd_pr__esd_pfet_g5v0d10v5 