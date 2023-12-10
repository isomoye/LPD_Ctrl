parameter int PNL_BRAM_ADDR_SIZE_NB   =   15;
parameter int PNL_BRAM_DBITS_WIDTH_NB =   PN_SIZE_NB;
parameter int PN__NB   =   12;
parameter int PN_PRECISION_NB =   4;
parameter int PN_SIZE_LB      =   4;
parameter int PN_SIZE_NB      =   PN__NB + PN_PRECISION_NB;
parameter int PNL_BRAM_NUM_WORDS_NB   =   2**PNL_BRAM_ADDR_SIZE_NB;
parameter int PN_BRAM_BASE   =   24576;

module Controller 
(
    //clk and reset
    input  logic clk,
    input  logic reset,
    //start and ready
    input  logic start,
    output logic ready,
    //load unload signals
    input  logic LM_ULM_ready,
    output logic LM_ULM_start,
    output logic [PNL_BRAM_ADDR_SIZE_NB-1 : 0] LM_ULM_base_address,
    output logic [PNL_BRAM_ADDR_SIZE_NB-1 : 0] LM_ULM_upper_limit,
    output logic LM_ULM_load_unload,
    //histogram signals
    input  logic Histo_ready,
    output logic Histo_start,
    output logic BRAM_select
);

//`include "kmeans_pkg.sv"

enum logic[3:0] {
    idle,
    wait_lM_ULM_load, 
    wait_Histo, 
    wait_LM_ULM_unload
} curr_state, next_state;

logic ready_c;
logic ready_r;

always_ff @( posedge clk ) begin : main_seq
    if (reset) begin
        curr_state <= idle;
        ready_r <= '1;
    end
    else begin
        curr_state <= next_state;
        ready_r <= ready_c;  
    end
end

always_comb begin : main_combo
    next_state = state;
    ready_c = ready_r;

    LM_ULM_start = '0;
    Histo_start = '0;

    LM_ULM_base_address = '0;
    LM_ULM_upper_limit = '0;
    LM_ULM_load_unload = '0;

    BRAM_select = '0;

    case (state)
        idle: begin
            ready_c = '1;
            if(start) begin
                ready_c = '0;
                
                //Start data load operation from C program
                LM_ULM_start = '1;

                //Setup memory base and upper_limit for loading of PNs into BRAM. ALWAYS SUBSTRACT 1 from the 'UPPER_LIMIT'
                LM_ULM_base_address = PN_BRAM_BASE;
                LM_ULM_upper_limit = PNL_BRAM_NUM_WORDS_NB -1;
                next_state = wait_lM_ULM_load;
            end
        end

        wait_lM_ULM_load: begin
            if(LM_ULM_ready) begin
                Histo_start = '1;
                BRAM_select = '1;
                next_state= wait_Histo;
            end
        end

        wait_Histo: begin
            BRAM_select = '1;
            if(Histo_ready) begin
                // Start memory output operation to C program
                LM_ULM_start = '1;
     
                // Setup memory base and upper_limit for unloading of histogram from BRAM. ALWAYS SUBSTRACT 1 from the 'UPPER_LIMIT'
                LM_ULM_base_address = HISTO_BRAM_BASE;
                LM_ULM_upper_limit = HISTO_BRAM_UPPER_LIMIT - 1;
     
                // Set LoadUnloadMem mode to 'unload' data from BRAM to C program
                LM_ULM_load_unload = '1;
                next_state = wait_LM_ULM_unload;
            end
        end

        wait_LM_ULM_unload: begin
            LM_ULM_load_unload = '1;
            if(LM_ULM_ready) begin
                next_state = idle;
            end
        end
    endcase
end

assign ready = ready_r;
endmodule