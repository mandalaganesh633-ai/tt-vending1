// ============================================================================
//  SMART VENDING MACHINE — Complete Synthesizable RTL
//  File: project.v
//  Version: 3.0
//
//  Features:
//    [x] FSM vending machine         (7 states)
//    [x] Multiple products           (A=5, B=7, C=9, D=10 rupees)
//    [x] Coins: 1, 2, 5, 10
//    [x] Money accumulator           (8-bit, saturation-safe)
//    [x] Cancel / refund logic
//    [x] Exact-change detection      (bypass optimizer)
//    [x] Coin inventory              (4 × 4-bit register file)
//    [x] Change optimizer            (greedy + availability-aware FSM)
//    [x] 7-segment display           (2-digit BCD)
//    [x] Fully synthesizable         (async reset, no latches)
//
//  Port Map (TOP: smart_vending_machine):
//    clk          - System clock (100 MHz recommended)
//    rst_n        - Active-low async reset
//    coin_valid   - 1-cycle pulse: coin inserted
//    coin_type    - 2b: 00=₹1  01=₹2  10=₹5  11=₹10
//    prod_sel     - 2b: 00=A   01=B   10=C   11=D
//    cancel_btn   - 1-cycle pulse: cancel/refund
//    seg_tens     - 7b: 7-seg tens  digit of total
//    seg_units    - 7b: 7-seg units digit of total
//    dispense_product - 1-cycle pulse: product vended
//    dispense_item    - 2b: which product
//    led_insert   - LED: waiting for coins
//    led_ready    - LED: enough money inserted
//    led_busy     - LED: transaction in progress
//    led_error    - LED: change error / call attendant
//    led_refund   - LED: refund in progress
//    dbg_state    - 3b: FSM state (debug)
//    dbg_total    - 8b: running total (debug)
//
//  FSM States:
//    3'd0 IDLE         3'd1 ACCEPT       3'd2 DISPENSE
//    3'd3 CALC_CHANGE  3'd4 GIVE_CHANGE  3'd5 REFUND
//    3'd6 ERROR
//
//  7-Segment Encoding (active-high, seg[6:0] = {g,f,e,d,c,b,a}):
//       aaa
//      f   b
//       ggg
//      e   c
//       ddd
// ============================================================================

`timescale 1ns/1ps

// ============================================================================
// MODULE 1 — coin_decoder
// Translates coin_type[1:0] → value; outputs value_valid for one clock cycle.
// ============================================================================
module coin_decoder (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       coin_valid,
    input  wire [1:0] coin_type,
    output reg  [3:0] coin_value,
    output reg        value_valid
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            coin_value  <= 4'd0;
            value_valid <= 1'b0;
        end else begin
            value_valid <= coin_valid;
            if (coin_valid) begin
                case (coin_type)
                    2'b00: coin_value <= 4'd1;
                    2'b01: coin_value <= 4'd2;
                    2'b10: coin_value <= 4'd5;
                    2'b11: coin_value <= 4'd10;
                    default: coin_value <= 4'd0;
                endcase
            end else
                coin_value <= 4'd0;
        end
    end
endmodule

// ============================================================================
// MODULE 2 — money_accumulator
// 8-bit running total; clears on clear_acc; saturates at 255.
// ============================================================================
module money_accumulator (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] coin_value,
    input  wire       value_valid,
    input  wire       clear_acc,
    output reg  [7:0] total
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            total <= 8'd0;
        else if (clear_acc)
            total <= 8'd0;
        else if (value_valid) begin
            if (total + {4'd0, coin_value} > 8'd255)
                total <= 8'd255;
            else
                total <= total + {4'd0, coin_value};
        end
    end
endmodule

// ============================================================================
// MODULE 3 — product_selector
// Pure combinational: prod_sel → price + validity flag.
// ============================================================================
module product_selector (
    input  wire [1:0] prod_sel,
    output reg  [3:0] price,
    output reg        valid_sel
);
    always @(*) begin
        case (prod_sel)
            2'b00: begin price = 4'd5;  valid_sel = 1'b1; end  // A
            2'b01: begin price = 4'd7;  valid_sel = 1'b1; end  // B
            2'b10: begin price = 4'd9;  valid_sel = 1'b1; end  // C
            2'b11: begin price = 4'd10; valid_sel = 1'b1; end  // D
            default: begin price = 4'd0; valid_sel = 1'b0; end
        endcase
    end
endmodule

// ============================================================================
// MODULE 4 — coin_inventory
// 4 × 4-bit register file. add on insert, subtract on change dispense.
// Pre-loaded float at reset.
// ============================================================================
module coin_inventory (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       add_valid,
    input  wire [1:0] add_denom,
    input  wire       sub_valid,
    input  wire [1:0] sub_denom,
    input  wire [3:0] sub_count,
    output wire [3:0] inv_d1,
    output wire [3:0] inv_d2,
    output wire [3:0] inv_d5,
    output wire [3:0] inv_d10
);
    reg [3:0] inv [0:3];  // [0]=₹1 [1]=₹2 [2]=₹5 [3]=₹10

    assign inv_d1  = inv[0];
    assign inv_d2  = inv[1];
    assign inv_d5  = inv[2];
    assign inv_d10 = inv[3];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            inv[0] <= 4'd10;  // 10×₹1
            inv[1] <= 4'd8;   //  8×₹2
            inv[2] <= 4'd6;   //  6×₹5
            inv[3] <= 4'd4;   //  4×₹10
        end else begin
            if (add_valid && inv[add_denom] < 4'd15)
                inv[add_denom] <= inv[add_denom] + 4'd1;
            if (sub_valid) begin
                if (inv[sub_denom] >= sub_count)
                    inv[sub_denom] <= inv[sub_denom] - sub_count;
                else
                    inv[sub_denom] <= 4'd0;
            end
        end
    end
endmodule

// ============================================================================
// MODULE 5 — change_optimizer
// Greedy 6-state FSM: ₹10→₹5→₹2→₹1
// Inventory latched at start. Completes in 6 clock cycles worst-case.
// done=1,error=0 → disp_d* valid   done=1,error=1 → insufficient coins
// ============================================================================
module change_optimizer (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [7:0] change_amount,
    input  wire [3:0] inv_d1,
    input  wire [3:0] inv_d2,
    input  wire [3:0] inv_d5,
    input  wire [3:0] inv_d10,
    output reg  [3:0] disp_d1,
    output reg  [3:0] disp_d2,
    output reg  [3:0] disp_d5,
    output reg  [3:0] disp_d10,
    output reg        done,
    output reg        error
);
    localparam [2:0]
        CO_IDLE = 3'd0, CO_D10 = 3'd1, CO_D5  = 3'd2,
        CO_D2   = 3'd3, CO_D1  = 3'd4, CO_DONE = 3'd5;

    reg [2:0] state;
    reg [7:0] rem;
    reg [3:0] s_d1, s_d2, s_d5, s_d10;  // latched inventory

    function automatic [3:0] use_coins;
        input [7:0] r;
        input [3:0] val;
        input [3:0] avail;
        reg   [7:0] needed;
        begin
            needed = r / val;
            use_coins = (needed > {4'd0, avail}) ? avail : needed[3:0];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= CO_IDLE; rem <= 8'd0;
            disp_d1<=4'd0; disp_d2<=4'd0; disp_d5<=4'd0; disp_d10<=4'd0;
            done<=1'b0; error<=1'b0;
            s_d1<=4'd0; s_d2<=4'd0; s_d5<=4'd0; s_d10<=4'd0;
        end else begin
            done <= 1'b0; error <= 1'b0;
            case (state)
                CO_IDLE: if (start) begin
                    s_d1<=inv_d1; s_d2<=inv_d2; s_d5<=inv_d5; s_d10<=inv_d10;
                    rem <= change_amount;
                    disp_d1<=4'd0; disp_d2<=4'd0; disp_d5<=4'd0; disp_d10<=4'd0;
                    state <= (change_amount==8'd0) ? CO_DONE : CO_D10;
                end
                CO_D10: begin
                    if (rem >= 8'd10) begin
                        disp_d10 <= use_coins(rem, 4'd10, s_d10);
                        rem <= rem - (use_coins(rem, 4'd10, s_d10) * 8'd10);
                    end
                    state <= CO_D5;
                end
                CO_D5: begin
                    if (rem >= 8'd5) begin
                        disp_d5 <= use_coins(rem, 4'd5, s_d5);
                        rem <= rem - (use_coins(rem, 4'd5, s_d5) * 8'd5);
                    end
                    state <= CO_D2;
                end
                CO_D2: begin
                    if (rem >= 8'd2) begin
                        disp_d2 <= use_coins(rem, 4'd2, s_d2);
                        rem <= rem - (use_coins(rem, 4'd2, s_d2) * 8'd2);
                    end
                    state <= CO_D1;
                end
                CO_D1: begin
                    if (rem >= 8'd1) begin
                        disp_d1 <= use_coins(rem, 4'd1, s_d1);
                        rem <= rem - use_coins(rem, 4'd1, s_d1);
                    end
                    state <= CO_DONE;
                end
                CO_DONE: begin
                    done  <= 1'b1;
                    error <= (rem != 8'd0);
                    state <= CO_IDLE;
                end
                default: state <= CO_IDLE;
            endcase
        end
    end
endmodule

// ============================================================================
// MODULE 6 — bcd_converter
// Double-dabble: 8-bit binary → BCD tens + units. Fully combinational.
// ============================================================================
module bcd_converter (
    input  wire [7:0] bin,
    output reg  [3:0] tens,
    output reg  [3:0] units
);
    reg [15:0] scratch;
    integer i;
    always @(*) begin
        scratch = 16'd0;
        scratch[7:0] = bin;
        for (i = 0; i < 8; i = i+1) begin
            if (scratch[11:8]  >= 4'd5) scratch[11:8]  = scratch[11:8]  + 4'd3;
            if (scratch[15:12] >= 4'd5) scratch[15:12] = scratch[15:12] + 4'd3;
            scratch = scratch << 1;
        end
        tens  = scratch[15:12];
        units = scratch[11:8];
    end
endmodule

// ============================================================================
// MODULE 7 — seg7_driver
// BCD digit → 7-segment active-high encoding. seg[6:0] = {g,f,e,d,c,b,a}
// ============================================================================
module seg7_driver (
    input  wire [3:0] digit,
    output reg  [6:0] seg
);
    always @(*) begin
        case (digit)                 // gfedcba
            4'd0: seg = 7'b0111111;
            4'd1: seg = 7'b0000110;
            4'd2: seg = 7'b1011011;
            4'd3: seg = 7'b1001111;
            4'd4: seg = 7'b1100110;
            4'd5: seg = 7'b1101101;
            4'd6: seg = 7'b1111101;
            4'd7: seg = 7'b0000111;
            4'd8: seg = 7'b1111111;
            4'd9: seg = 7'b1101111;
            default: seg = 7'b1000000; // dash
        endcase
    end
endmodule

// ============================================================================
// MODULE 8 — fsm_controller
// Master 7-state transaction FSM.
//
//  IDLE → ACCEPT → DISPENSE → CALC_CHANGE → GIVE_CHANGE → IDLE
//  ACCEPT   → (cancel)  → REFUND   → GIVE_CHANGE → IDLE
//  *        → (error)   → ERROR    (hold until reset)
// ============================================================================
module fsm_controller (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] total,
    input  wire [3:0] price,
    input  wire       valid_sel,
    input  wire       cancel_btn,
    input  wire [1:0] prod_sel,
    // Change optimizer
    input  wire       change_done,
    input  wire       change_error,
    input  wire [3:0] disp_d1,
    input  wire [3:0] disp_d2,
    input  wire [3:0] disp_d5,
    input  wire [3:0] disp_d10,
    output reg        change_start,
    output reg  [7:0] change_amount,
    // Inventory subtract
    output reg        sub_valid,
    output reg  [1:0] sub_denom,
    output reg  [3:0] sub_count,
    // Accumulator
    output reg        clear_acc,
    // Product
    output reg        dispense_product,
    output reg  [1:0] dispense_item,
    // LEDs
    output reg        led_insert,
    output reg        led_ready,
    output reg        led_busy,
    output reg        led_error,
    output reg        led_refund,
    // Debug
    output wire [2:0] dbg_state
);
    localparam [2:0]
        S_IDLE=3'd0, S_ACCEPT=3'd1, S_DISPENSE=3'd2,
        S_CALC=3'd3, S_GIVE=3'd4,   S_REFUND=3'd5, S_ERROR=3'd6;

    reg [2:0] state;
    reg [1:0] chg_step;
    reg [3:0] r_d1, r_d2, r_d5, r_d10;

    assign dbg_state = state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=S_IDLE; chg_step<=2'd0;
            change_start<=1'b0; change_amount<=8'd0;
            sub_valid<=1'b0; sub_denom<=2'd0; sub_count<=4'd0;
            clear_acc<=1'b0; dispense_product<=1'b0; dispense_item<=2'd0;
            led_insert<=1'b1; led_ready<=1'b0; led_busy<=1'b0;
            led_error<=1'b0;  led_refund<=1'b0;
            r_d1<=4'd0; r_d2<=4'd0; r_d5<=4'd0; r_d10<=4'd0;
        end else begin
            // Default deasserts — prevents latches
            sub_valid<=1'b0; clear_acc<=1'b0;
            dispense_product<=1'b0; change_start<=1'b0;

            case (state)
                S_IDLE: begin
                    led_insert<=1'b1; led_ready<=1'b0; led_busy<=1'b0;
                    led_error<=1'b0;  led_refund<=1'b0; chg_step<=2'd0;
                    if (total > 8'd0 && valid_sel) state <= S_ACCEPT;
                end

                S_ACCEPT: begin
                    led_insert<=1'b0; led_busy<=1'b1;
                    if (cancel_btn) state <= S_REFUND;
                    else if (total >= {4'd0, price}) begin
                        led_ready <= 1'b1; state <= S_DISPENSE;
                    end
                end

                S_DISPENSE: begin
                    dispense_product <= 1'b1;
                    dispense_item    <= prod_sel;
                    if (total == {4'd0, price}) begin
                        clear_acc <= 1'b1; state <= S_IDLE;
                    end else begin
                        change_amount <= total - {4'd0, price};
                        state <= S_CALC;
                    end
                end

                S_CALC: begin
                    change_start <= 1'b1;
                    if (change_done) begin
                        if (change_error) state <= S_ERROR;
                        else begin
                            r_d1<=disp_d1; r_d2<=disp_d2;
                            r_d5<=disp_d5; r_d10<=disp_d10;
                            chg_step<=2'd0; state<=S_GIVE;
                        end
                    end
                end

                S_GIVE: begin
                    case (chg_step)
                        2'd0: begin
                            if (r_d10>4'd0) begin
                                sub_valid<=1'b1; sub_denom<=2'b11; sub_count<=r_d10;
                            end
                            chg_step<=2'd1;
                        end
                        2'd1: begin
                            if (r_d5>4'd0) begin
                                sub_valid<=1'b1; sub_denom<=2'b10; sub_count<=r_d5;
                            end
                            chg_step<=2'd2;
                        end
                        2'd2: begin
                            if (r_d2>4'd0) begin
                                sub_valid<=1'b1; sub_denom<=2'b01; sub_count<=r_d2;
                            end
                            chg_step<=2'd3;
                        end
                        2'd3: begin
                            if (r_d1>4'd0) begin
                                sub_valid<=1'b1; sub_denom<=2'b00; sub_count<=r_d1;
                            end
                            clear_acc<=1'b1; state<=S_IDLE;
                        end
                        default: state<=S_IDLE;
                    endcase
                end

                S_REFUND: begin
                    led_refund<=1'b1; change_amount<=total; change_start<=1'b1;
                    if (change_done) begin
                        if (change_error) state<=S_ERROR;
                        else begin
                            r_d1<=disp_d1; r_d2<=disp_d2;
                            r_d5<=disp_d5; r_d10<=disp_d10;
                            chg_step<=2'd0; state<=S_GIVE;
                        end
                    end
                end

                S_ERROR: begin
                    led_error<=1'b1; led_busy<=1'b0;
                    led_ready<=1'b0; led_refund<=1'b0;
                    // Hold until rst_n (attendant clears)
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

// ============================================================================
// MODULE 9 — smart_vending_machine  (TOP LEVEL / SYNTHESIS BOUNDARY)
// ============================================================================
module smart_vending_machine (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       coin_valid,
    input  wire [1:0] coin_type,
    input  wire [1:0] prod_sel,
    input  wire       cancel_btn,
    output wire [6:0] seg_tens,
    output wire [6:0] seg_units,
    output wire       dispense_product,
    output wire [1:0] dispense_item,
    output wire       led_insert,
    output wire       led_ready,
    output wire       led_busy,
    output wire       led_error,
    output wire       led_refund,
    output wire [2:0] dbg_state,
    output wire [7:0] dbg_total
);
    // Internal wires
    wire [3:0] coin_value;
    wire       value_valid;
    wire [7:0] total;
    wire       clear_acc;
    wire [3:0] price;
    wire       valid_sel;
    wire       sub_valid;
    wire [1:0] sub_denom;
    wire [3:0] sub_count;
    wire [3:0] inv_d1, inv_d2, inv_d5, inv_d10;
    wire       change_start;
    wire [7:0] change_amount;
    wire       change_done, change_error;
    wire [3:0] disp_d1, disp_d2, disp_d5, disp_d10;
    wire [3:0] bcd_tens_w, bcd_units_w;

    assign dbg_total = total;

    coin_decoder u_dec (
        .clk(clk), .rst_n(rst_n),
        .coin_valid(coin_valid), .coin_type(coin_type),
        .coin_value(coin_value), .value_valid(value_valid)
    );
    money_accumulator u_acc (
        .clk(clk), .rst_n(rst_n),
        .coin_value(coin_value), .value_valid(value_valid),
        .clear_acc(clear_acc), .total(total)
    );
    product_selector u_prod (
        .prod_sel(prod_sel), .price(price), .valid_sel(valid_sel)
    );
    coin_inventory u_inv (
        .clk(clk), .rst_n(rst_n),
        .add_valid(value_valid), .add_denom(coin_type),
        .sub_valid(sub_valid),   .sub_denom(sub_denom), .sub_count(sub_count),
        .inv_d1(inv_d1), .inv_d2(inv_d2), .inv_d5(inv_d5), .inv_d10(inv_d10)
    );
    change_optimizer u_opt (
        .clk(clk), .rst_n(rst_n),
        .start(change_start), .change_amount(change_amount),
        .inv_d1(inv_d1), .inv_d2(inv_d2), .inv_d5(inv_d5), .inv_d10(inv_d10),
        .disp_d1(disp_d1), .disp_d2(disp_d2), .disp_d5(disp_d5), .disp_d10(disp_d10),
        .done(change_done), .error(change_error)
    );
    fsm_controller u_fsm (
        .clk(clk), .rst_n(rst_n),
        .total(total), .price(price), .valid_sel(valid_sel),
        .cancel_btn(cancel_btn), .prod_sel(prod_sel),
        .change_done(change_done), .change_error(change_error),
        .disp_d1(disp_d1), .disp_d2(disp_d2), .disp_d5(disp_d5), .disp_d10(disp_d10),
        .change_start(change_start), .change_amount(change_amount),
        .sub_valid(sub_valid), .sub_denom(sub_denom), .sub_count(sub_count),
        .clear_acc(clear_acc),
        .dispense_product(dispense_product), .dispense_item(dispense_item),
        .led_insert(led_insert), .led_ready(led_ready), .led_busy(led_busy),
        .led_error(led_error),   .led_refund(led_refund), .dbg_state(dbg_state)
    );
    bcd_converter u_bcd (
        .bin(total), .tens(bcd_tens_w), .units(bcd_units_w)
    );
    seg7_driver u_seg_t (.digit(bcd_tens_w),  .seg(seg_tens));
    seg7_driver u_seg_u (.digit(bcd_units_w), .seg(seg_units));

endmodule
