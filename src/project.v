// /*
//  * Copyright (c) 2024 Mandala Ganesh
//  * SPDX-License-Identifier: Apache-2.0
//  */

// `default_nettype none

// module tt_um_example (
//     input  wire [7:0] ui_in,    // Dedicated inputs
//     output wire [7:0] uo_out,   // Dedicated outputs
//     input  wire [7:0] uio_in,   // IOs: Input path
//     output wire [7:0] uio_out,  // IOs: Output path
//     output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
//     input  wire       ena,      // always 1 when the design is powered, so you can ignore it
//     input  wire       clk,      // clock
//     input  wire       rst_n     // reset_n - low to reset
// );

//   // All output pins must be assigned. If not used, assign to 0.
//   assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
//   assign uio_out = 0;
//   assign uio_oe  = 0;

//   // List all unused inputs to prevent warnings
//   wire _unused = &{ena, clk, rst_n, 1'b0};

// endmodule

/*
 * Smart Vending Machine — Tiny Tapeout Wrapper
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // ================= INPUT DECODE =================
    wire [1:0] coin_type  = ui_in[1:0];
    wire       coin_valid = ui_in[2];
    wire [1:0] prod_sel   = ui_in[4:3];
    wire       cancel_btn = ui_in[5];

    // ================= OUTPUT WIRES =================
    wire [6:0] seg_units;
    wire [6:0] seg_tens;
    wire dispense_product;

    wire [1:0] dispense_item;
    wire led_insert, led_ready, led_busy, led_error, led_refund;
    wire [2:0] dbg_state;
    wire [7:0] dbg_total;

    // ================= DUT =================
    smart_vending_machine dut (
        .clk(clk),
        .rst_n(rst_n),
        .coin_valid(coin_valid),
        .coin_type(coin_type),
        .prod_sel(prod_sel),
        .cancel_btn(cancel_btn),

        .seg_tens(seg_tens),
        .seg_units(seg_units),

        .dispense_product(dispense_product),
        .dispense_item(dispense_item),

        .led_insert(led_insert),
        .led_ready(led_ready),
        .led_busy(led_busy),
        .led_error(led_error),
        .led_refund(led_refund),

        .dbg_state(dbg_state),
        .dbg_total(dbg_total)
    );

    // ================= OUTPUT MAPPING =================
    assign uo_out[6:0] = seg_units;       // show units digit
    assign uo_out[7]   = dispense_product;

    // ================= UNUSED IO =================
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    wire _unused = &{ena, uio_in, seg_tens, dbg_state, dbg_total, 1'b0};

endmodule

