//-------------------------------------------------------------------------
// Interface
//-------------------------------------------------------------------------
interface num_intf #();
  logic [`GPIO_WORD_SIZE_BITS_NB - 1:0] vals;
  logic [`GPIO_WORD_SIZE_BITS_NB - 1:0] clusters;
  logic [`GPIO_WORD_SIZE_BITS_NB - 1:0] dims;
endinterface
