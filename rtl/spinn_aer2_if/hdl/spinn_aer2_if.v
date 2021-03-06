// -------------------------------------------------------------------------
// $Id: spinn_aer2_if.v 2644 2013-10-24 15:18:41Z plana $
// -------------------------------------------------------------------------
// COPYRIGHT
// Copyright (c) The University of Manchester, 2012. All rights reserved.
// SpiNNaker Project
// Advanced Processor Technologies Group
// School of Computer Science
// -------------------------------------------------------------------------
// Project            : bidirectional SpiNNaker link to AER device interface
// Module             : top-level module
// Author             : lap/Jeff Pepper/Simon Davidson
// Status             : Review pending
// $HeadURL: https://solem.cs.man.ac.uk/svn/spinn_aer2_if/spinn_aer2_if.v $
// Last modified on   : $Date: 2013-10-24 16:18:41 +0100 (Thu, 24 Oct 2013) $
// Last modified by   : $Author: plana $
// Version            : $Revision: 2644 $
// -------------------------------------------------------------------------


//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//------------------------ spinn_aer2_if ------------------------
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
`timescale 1ns / 1ps
module spinn_aer2_if 
#(
  // debouncer constant (can be adjusted for simulation!)
  parameter DBNCER_CONST = 20'hfffff
)
(
  input wire         ext_nreset,
  input wire         ext_clk,

  // display interface (7-segment and leds)
  input  wire        ext_mode_sel,
  output wire  [7:0] ext_7seg,
  output wire  [3:0] ext_strobe,
  output wire        ext_led2,
  output wire        ext_led3,
  output wire        ext_led4,
  output wire        ext_led5,

  // input SpiNNaker link interface
  input  wire  [6:0] data_2of7_from_spinnaker,
  output wire        ack_to_spinnaker,

  // output SpiNNaker link interface
  output wire  [6:0] data_2of7_to_spinnaker,
  input  wire        ack_from_spinnaker,

  // input AER device interface
  input  wire [15:0] iaer_data,
  input  wire        iaer_req,
  output wire        iaer_ack,

  // output AER device interface
  output wire [15:0] oaer_data,
  output wire        oaer_req,
  input  wire        oaer_ack
);
  //---------------------------------------------------------------
  // options
  //---------------------------------------------------------------


  //---------------------------------------------------------------
  // constants
  //---------------------------------------------------------------
  localparam MODE_BITS = 4;


  //---------------------------------------------------------------
  // internal signals
  //---------------------------------------------------------------
  // control signals
  // ---------------------------------------------------------
  wire        i_nreset;
  reg         rst_unlocked;
  wire        rst;
  wire        cg_locked;

  wire        clk;
  wire        clk_32;
  wire        clk_64;
  wire        clk_96;

  wire        clk_vio;
  wire        clk_sync;
  wire        clk_mod;
  wire        clk_deb;

  // internal SpiNNaker interface signals
  // ---------------------------------------------------------
  wire  [6:0] i_ispinn_data;
  wire  [6:0] s_ispinn_data;  // synchronized signal 
  wire        i_ispinn_ack;

  wire  [6:0] i_ospinn_data;
  wire        i_ospinn_ack;
  wire        s_ospinn_ack;  // synchronized signal 

  // internal AER interface signals
  // ---------------------------------------------------------
  wire [15:0] i_iaer_data;
  wire        i_iaer_req;
  wire        s_iaer_req;  // synchronized signal 
  wire        i_iaer_ack;

  wire [15:0] i_oaer_data;
  wire        i_oaer_req;
  wire        i_oaer_ack;
  wire        s_oaer_ack;  // synchronized signal 

  // internal packet data and hadshake signals
  // ---------------------------------------------------------
  wire [71:0] opkt_data;
  wire        opkt_vld;
  wire        opkt_rdy;

  wire [71:0] ipkt_data;
  wire        ipkt_vld;
  wire        ipkt_rdy;

  // signals for user interface
  // ---------------------------------------------------------
  wire  [MODE_BITS - 1:0] mode;
  wire                    dump_mode;
  wire              [7:0] o_7seg;
  wire              [3:0] o_strobe;
  wire                    led2;
  wire                    led5;
  //---------------------------------------------------------------


  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //------------------------- synchronisers -----------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //---------------------------------------------------------------
  // synchronize the AER_IN asynchronous request line
  // NOTE: AER request is active LOW -- initialize to HIGH
  //---------------------------------------------------------------
  synchronizer
  #(
    .SIZE  (1),
    .DEPTH (2)
  ) sreq
  (
    .clk (clk_sync),
    .in  (i_iaer_req),
    .out (s_iaer_req)
   );
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // synchronize the AER_OUT asynchronous ack line
  // NOTE: AER ack is active LOW -- initialize to HIGH
  //---------------------------------------------------------------
  synchronizer
  #(
    .SIZE  (1),
    .DEPTH (2)
  ) sack
  (
    .clk (clk_sync),
    .in  (i_oaer_ack),
    .out (s_oaer_ack)
   );
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // Synchronise the output SpiNNaker async i/f ack
  //---------------------------------------------------------------
  synchronizer
  #(
    .SIZE  (1),
    .DEPTH (2)
  ) ssack
  (
    .clk (clk_sync),
    .in  (i_ospinn_ack),
    .out (s_ospinn_ack)
   );
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // Synchronise the input SpiNNaker async i/f data
  //---------------------------------------------------------------
  synchronizer
  #(
    .SIZE  (7),
    .DEPTH (2)
  ) sdat
  (
    .clk (clk_sync),
    .in  (i_ispinn_data),
    .out (s_ispinn_data)
   );
  //---------------------------------------------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //------------------------ spinn_receiver -----------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  spinn_receiver sr
  (
    .rst       (rst),
    .clk       (clk_mod),
    .err       (led5),
    .data_2of7 (s_ispinn_data),
    .ack       (i_ispinn_ack),
    .pkt_data  (opkt_data),
    .pkt_vld   (opkt_vld),
    .pkt_rdy   (opkt_rdy)
  );
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //------------------------- out_mapper --------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  out_mapper om
  (
    .rst       (rst),
    .clk       (clk_mod),
    .opkt_data (opkt_data),
    .opkt_vld  (opkt_vld),
    .opkt_rdy  (opkt_rdy),
    .oaer_data (i_oaer_data),
    .oaer_req  (i_oaer_req),
    .oaer_ack  (s_oaer_ack)
  );
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //-------------------------- in_mapper --------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  in_mapper
  #(
    .MODE_BITS (MODE_BITS)
  ) im
  (
    .rst       (rst),
    .clk       (clk_mod),
    .mode      (mode),
    .dump_mode (dump_mode),
    .iaer_data (i_iaer_data),
    .iaer_req  (s_iaer_req),
    .iaer_ack  (i_iaer_ack),
    .ipkt_data (ipkt_data),
    .ipkt_vld  (ipkt_vld),
    .ipkt_rdy  (ipkt_rdy)
  );
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //------------------------- spinn_driver ------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  spinn_driver sd
  (
    .rst       (rst),
    .clk       (clk_mod),
    .pkt_data  (ipkt_data),
    .pkt_vld   (ipkt_vld),
    .pkt_rdy   (ipkt_rdy),
    .data_2of7 (i_ospinn_data),
    .ack       (s_ospinn_ack)
  );
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 
  
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //------------------------ user_interface -----------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  user_int
  #(
    .DBNCER_CONST (DBNCER_CONST),
    .MODE_BITS    (MODE_BITS)
  ) ui
  (
    .rst          (rst),
    .clk          (clk_deb),
    .mode         (mode),
    .mode_sel     (mode_sel),
    .o_7seg       (o_7seg),
    .o_strobe     (o_strobe),
    .o_led2       (led2)
  );
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //------------------------ clock and reset ----------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //---------------------------------------------------------------
  // debounce reset pushbutton
  //---------------------------------------------------------------
  reg [19:0] debounce_state;
  reg  [2:0] bounce;

  always @(posedge clk_deb)
  begin
    bounce[0] <= ~i_nreset;  
    bounce[1] <= bounce[0];
    bounce[2] <= bounce[1];
  end

  always @(posedge clk_deb)
    if (bounce[2] != bounce[1]) 
      debounce_state <= DBNCER_CONST;
    else
      if (debounce_state != 0)
        debounce_state <= debounce_state - 1;
      else
        debounce_state <= debounce_state;  // no change!

  always @(posedge clk_deb)
    if ((bounce[2] == bounce[1]) && (debounce_state == 0))
        rst_unlocked <= bounce[2];
      else
        rst_unlocked <= rst_unlocked;  // no change!
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // generate reset signal -- keep it active until clkgen locked!
  //---------------------------------------------------------------
  assign rst = rst_unlocked || !cg_locked;
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // clock generation module
  //---------------------------------------------------------------
  assign clk_deb  = clk_32;
  assign clk_vio  = clk_32;
  assign clk_sync = clk_32;
  assign clk_mod  = clk_32;

  clkgen cg 
  (
    .CLK_OUT1 (clk_32),
    .CLK_OUT2 (clk_96),
    .CLK_OUT3 (clk_64),
    .CLK_IN1  (clk),
    .LOCKED   (cg_locked),
    .RESET    (~i_nreset)
  );
  //---------------------------------------------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //-------------------------- I/O buffers ------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //---------------------------------------------------------------
  // control and status signals
  //---------------------------------------------------------------
  IBUFG ext_clk_buf   (.I (ext_clk),      .O (clk));
  IBUF  nreset_buf    (.I (ext_nreset),   .O (i_nreset));
  OBUF  act_led_buf   (.I (led2),         .O (ext_led2));
  OBUF  reset_led_buf (.I (rst),          .O (ext_led3));
  OBUF  dump_mode_buf (.I (dump_mode),    .O (ext_led4));
  OBUF  debug_buf     (.I (led5),         .O (ext_led5));
  IBUF  mode_sel_buf  (.I (ext_mode_sel), .O (mode_sel));
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // Asynchronous 2-of-7 interface between FPGA and Spinnaker chip
  //---------------------------------------------------------------
  OBUF dataOutToCore[6:0]  (.I (i_ospinn_data),
                            .O (data_2of7_to_spinnaker)
                           );
  IBUF ackInFromCore       (.I (ack_from_spinnaker),
                            .O (i_ospinn_ack)
                           );

  IBUF dataInFromCore[6:0] (.I (data_2of7_from_spinnaker),
                            .O (i_ispinn_data)
                           );
  OBUF ackOutToCore        (.I (i_ispinn_ack),
                            .O (ack_to_spinnaker)
                           );
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // Asynchronous interface between AER interfaces and FPGA
  //---------------------------------------------------------------
  IBUF iaer_req_buf        (.I (iaer_req),    .O (i_iaer_req));
  IBUF iaer_data_buf[15:0] (.I (iaer_data),   .O (i_iaer_data));
  OBUF iaer_ack_buf        (.I (i_iaer_ack),  .O (iaer_ack));

  OBUF oaer_req_buf        (.I (i_oaer_req),  .O (oaer_req));
  OBUF oaer_data_buf[15:0] (.I (i_oaer_data), .O (oaer_data));
  IBUF oaer_ack_buf        (.I (oaer_ack),    .O (i_oaer_ack));
  //---------------------------------------------------------------

  // ---------------------------------------------------------
  // Instantiate I/O buffers for 7-segment display
  // ---------------------------------------------------------
  OBUF  sevenSeg_buf0 (.I (o_7seg[0]),   .O (ext_7seg[0]));
  OBUF  sevenSeg_buf1 (.I (o_7seg[1]),   .O (ext_7seg[1]));
  OBUF  sevenSeg_buf2 (.I (o_7seg[2]),   .O (ext_7seg[2]));
  OBUF  sevenSeg_buf3 (.I (o_7seg[3]),   .O (ext_7seg[3]));
  OBUF  sevenSeg_buf4 (.I (o_7seg[4]),   .O (ext_7seg[4]));
  OBUF  sevenSeg_buf5 (.I (o_7seg[5]),   .O (ext_7seg[5]));
  OBUF  sevenSeg_buf6 (.I (o_7seg[6]),   .O (ext_7seg[6]));
  OBUF  sevenSeg_buf7 (.I (o_7seg[7]),   .O (ext_7seg[7]));

  OBUF  strobe_buf0   (.I (o_strobe[0]), .O (ext_strobe[0]));
  OBUF  strobe_buf1   (.I (o_strobe[1]), .O (ext_strobe[1]));
  OBUF  strobe_buf2   (.I (o_strobe[2]), .O (ext_strobe[2]));
  OBUF  strobe_buf3   (.I (o_strobe[3]), .O (ext_strobe[3]));
  // ---------------------------------------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
endmodule
