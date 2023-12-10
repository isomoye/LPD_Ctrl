//-------------------------------------------------------------------------
// Interface
//-------------------------------------------------------------------------
interface mem_intf #(
    parameter  WORD_SIZE = 64,
    localparam ADDR_SIZE = $clog2(WORD_SIZE)
);
  logic [ADDR_SIZE-1 : 0] addr;
  logic                   we;
  logic [WORD_SIZE-1 : 0] dout;
  logic [WORD_SIZE-1 : 0] din;
endinterface
