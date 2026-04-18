/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // ================= INPUT DECODE =================
    // Mapping to match your info.yaml:
    wire       coin_valid = ui_in[0];
    wire [1:0] coin_type  = ui_in[2:1];
    wire [1:0] prod_sel   = ui_in[4:3];
    wire       cancel_btn = ui_in[5];

    // ================= INTERNAL WIRES =================
    wire [6:0] seg_units;
    wire [6:0] seg_tens;
    wire       dispense_product;
    wire       led_busy;

    // ================= OUTPUT MAPPING =================
    assign uo_out[6:0] = seg_units;       // Show units digit
    assign uo_out[7]   = dispense_product;

    assign uio_out[6:0] = seg_tens;        // Show tens digit
    assign uio_out[7]   = led_busy;        // Status: Busy
    assign uio_oe       = 8'b11111111;     // All bi-dir pins are outputs

    // Unused inputs to prevent warnings
    wire _unused = &{ena, uio_in, ui_in[7:6], 1'b0};

    // ================= VENDING MACHINE CORE =================
    // This is the core logic inside the wrapper
    smart_vending_machine_core core (
        .clk(clk),
        .rst_n(rst_n),
        .coin_valid(coin_valid),
        .coin_type(coin_type),
        .prod_sel(prod_sel),
        .cancel_btn(cancel_btn),
        .seg_tens(seg_tens),
        .seg_units(seg_units),
        .dispense_product(dispense_product),
        .led_busy(led_busy)
    );

endmodule

// ============================================================================
//  VENDING MACHINE CORE LOGIC
// ============================================================================
// Includes FSM, Change Optimizer, Inventory, and 7-Segment Drivers

module smart_vending_machine_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        coin_valid,
    input  wire [1:0]  coin_type,
    input  wire [1:0]  prod_sel,
    input  wire        cancel_btn,
    output wire [6:0]  seg_tens,
    output wire [6:0]  seg_units,
    output wire        dispense_product,
    output wire        led_busy
);
    // ... Sub-module logic for all components goes here ...
    // Note: I recommend using the full consolidated file I generated earlier 
    // at C:/Users/manda/.gemini/antigravity/scratch/smart-vending-sim/src/project.v
endmodule
