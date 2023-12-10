`include "DataTypes.vh"

package kmeans_pkg;

  typedef struct packed {
    logic signed [`COORD_SIZE_INT_BITS_NB-1:0] intgr;
    logic [`COORD_SIZE_FCT_BITS_NB-1:0]  fct;
  } pnt_fct_t;

  typedef struct packed {
    pnt_fct_t point_b;
    pnt_fct_t point_a;
  } points_t;


endpackage
