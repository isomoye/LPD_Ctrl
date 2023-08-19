module CopyAssignmentArray(
    input  logic clk,
    input  logic reset,
    //start and ready
    input  logic start,
    output logic ready,
    //PNL signals
    input  logic [PNL_BRAM_DBITS_WIDTH_NB-1:0] PNL_BRAM_dout,
    output logic [PNL_BRAM_DBITS_WIDTH_NB-1:0] PNL_BRAM_addr,
    output logic [PNL_BRAM_DBITS_WIDTH_NB-1:0] PNL_BRAM_din,
    output logic [0:0] PNL_BRAM_we,

    input logic [PNL_BRAM_ADDR_SIZE_NB - 1:0] Num_Vals   ,  
    input logic [PNL_BRAM_ADDR_SIZE_NB - 1:0] SRC_BRAM_addr,
    input logic [PNL_BRAM_ADDR_SIZE_NB - 1:0] TGT_BRAM_addr
);


    enum logic [2:0] {
        idle, 
        get_cluster_addr, 
        get_cluster_val, 
        store_val
    } curr_state, next_state;

    logic ready_c;
    logic ready_r;
    logic [PNL_BRAM_ADDR_SIZE_NB-1:0] PN_addr_c;
    logic [PNL_BRAM_ADDR_SIZE_NB-1:0] PN_addr_r;
    logic [PNL_BRAM_ADDR_SIZE_NB-1:0] cluster_addr_c;
    logic [PNL_BRAM_ADDR_SIZE_NB-1:0] cluster_addr_r;

    logic [PNL_BRAM_ADDR_SIZE_NB-1:0] dist_count_c;
    logic [PNL_BRAM_ADDR_SIZE_NB-1:0] dist_count_r;

    logic do_PN_cluster_addr;

    logic  [PNL_BRAM_DBITS_WIDTH_NB-1:0] cluster_val_c;
    logic  [PNL_BRAM_DBITS_WIDTH_NB-1:0] cluster_val_r;

    logic  [PNL_BRAM_DBITS_WIDTH_NB-1:0] copy_cluster_c;
    logic  [PNL_BRAM_DBITS_WIDTH_NB-1:0] copy_cluster_r;

    always_ff @( posedge clk ) begin : main_seq
        if(reset) begin
            curr_state     <= idle;
            ready_r        <= '1;
            PN_addr_r      <= '0;
            cluster_val_r  <= '0;
            cluster_addr_r <= '0;
            dist_count_r   <= '0;
            copy_cluster_r <= '0; 
        end
        else begin
            curr_state       <= next_state;
            ready_r        <= ready_c        ;
            PN_addr_r      <= PN_addr_c      ;
            cluster_val_r  <= cluster_val_c  ;
            cluster_addr_r <= cluster_addr_c ;
            dist_count_r   <= dist_count_c   ;
            copy_cluster_r <= copy_cluster_c ; 
        end
    end


    always_comb begin : main_combo
        next_state = curr_state;
        ready_c = ready_r;

        PN_addr_c = PN_addr_r;
        cluster_addr_c = cluster_addr_r;
        cluster_val_c = cluster_val_r;

        copy_cluster_c = copy_cluster_r;
        dist_count_c  = dist_count_r;

        PNL_BRAM_we = '0;
        do_PN_cluster_addr = '0;
        
        case (curr_state)
            idle: begin
                ready_c = '1;
                if(start) begin
                    ready_c = '0;

					//Assert 'we' to zero out the first cell at 0.
					//PNL_BRAM_we <= "1";
					copy_cluster_c =  '0;
					cluster_val_c  =  '0;
					dist_count_c   =  '0;
					PN_addr_c      =  '0;
					cluster_addr_c =  '0;
					next_state     = get_cluster_addr;
                end
            end
            get_cluster_addr: begin
                if (dist_count_r >= (Num_Vals - 1)) begin
					next_state = idle;
                end
				else
					//	points_addr_next <= to_unsigned(KMEANS_PN_BRAM_LOWER_LIMIT,PNL_BRAM_ADDR_SIZE_NB) 
					//	+ (dist_count_reg * dims_count);
					PN_addr_c = SRC_BRAM_addr + dist_count_r;
					next_state   = get_cluster_val;
				end if;
            end 
            get_cluster_val: begin
                cluster_val_c = PNL_BRAM_dout;
                next_state = store_val;
                
            end 
            store_val: begin
                PNL_BRAM_din = cluster_val_r;
                PNL_BRAM_we = '1;
                do_PN_cluster_addr = '1;
                cluster_addr_c = TGT_BRAM_addr + dist_count_r;
                dist_count_c = dist_count_r + 1;
                next_state = get_cluster_addr;
            end

            default: begin
                default_case
            end
        endcase
    end

    assign PNL_BRAM_addr = do_PN_cluster_addr ? cluster_addr_c : PN_addr_c;
    assign ready = ready_r; 



endmodule