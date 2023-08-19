Module LoadUnLoadMem(
    input  logic clk,
    input  logic reset,
    //start and ready
    input  logic start,
    output logic ready,
    //memory signals
    input  logic load_unload,
    output logic stopped,
    input logic continue,
    input logic done,
    //base signals
    input logic  [PNL_BRAM_ADDR_SIZE_NB-1:0] base_address,
    input logic  [PNL_BRAM_ADDR_SIZE_NB-1:0] upper_limit ,
    //CP signals
    input logic  [WORD_SIZE_NB-1:0] CP_in_word,
    output logic [WORD_SIZE_NB-1:0] CP_out_word,
    //PNL signals
    input  logic [PNL_BRAM_DBITS_WIDTH_NB-1:0] PNL_BRAM_dout,
    output logic [PNL_BRAM_DBITS_WIDTH_NB-1:0] PNL_BRAM_addr,
    output logic [PNL_BRAM_DBITS_WIDTH_NB-1:0] PNL_BRAM_din,
    output logic [0:0] PNL_BRAM_we
);

    enum logic [2:0] {
        idle, 
        load_mem, 
        unload_mem, 
        wait_load_unload, 
        wait_done
    } curr_state, next_state

    logic ready_c;
    logic ready_r;
    logic [PNL_BRAM_DBITS_WIDTH_NB-1:0] PNL_BRAM_addr_c;
    logic [PNL_BRAM_DBITS_WIDTH_NB-1:0] PNL_BRAM_addr_r;
    logic  [PNL_BRAM_ADDR_SIZE_NB-1:0] upper_limit_c;
    logic  [PNL_BRAM_ADDR_SIZE_NB-1:0] upper_limit_r;

    always_ff @( posedge clk ) begin : main_seq
        if (reset) begin
            curr_state <= idle;
            ready_r <= '1;
            PNL_BRAM_addr_r <= '0;
            upper_limit_r <= '0;
        end
        else begin
            curr_state <= next_state;
            ready_r <= ready_c;  
            PNL_BRAM_addr_r <= PNL_BRAM_addr_c;
            upper_limit_r <= upper_limit_c;
        end
    end

    always_comb begin : main_combo
        next_state = curr_state;
        ready_c = ready_r;

        PNL_BRAM_addr_c = PNL_BRAM_addr_r;
        upper_limit_c = upper_limit_r;
    
        PNL_BRAM_we = '0;
        PNL_BRAM_din = '0;
        CP_out_word = '0;

        stopped = '0;
    
        case (state)
            idle: begin
                ready_c = '1;
                PNL_BRAM_addr_c = base_address;
                upper_limit_c = upper_limit;
                if(!load_unload) begin
                    next_state = load_mem;
                end
                else begin
                    next_state = unload_mem;
                end

            end

            load_mem: begin
                stopped = '1;
                if(!done) begin
                    PNL_BRAM_we = '1;
                    PNL_BRAM_din = (PNL_BRAM_DBITS_WIDTH_NB-1)'b0 & CP_in_word;

                    next_state = wait_load_unload;
                end
            end

            unload_mem: begin
                CP_out_word = PNL_BRAM_dout;
                stopped = '1;
                if(continue) begin
                    next_state = wait_load_unload;
                end
                else if(done) begin
                    next_state = wait_done;
                end
                
            end
            wait_load_unload: begin
                if(!continue) begin
                    if(done) begin
                        next_state = wait_done;
                    end
                    else if(PNL_BRAM_addr_r >= upper_limit_r) begin
                        next_state = idle;
                    end
                    else begin
                        PNL_BRAM_addr_c = PNL_BRAM_addr_r + 1;
                        if(!load_unload) begin
                            next_state = load_mem;
                        end
                        else begin
                            next_state = unload_mem;
                        end
                    end
                end
            end
            wait_done: begin
                if(!done) begin
                    next_state = idle;
                end
            end
   assign PNL_BRAM_addr = PNL_BRAM_addr_r;
   assign ready = ready_r;

endmodule