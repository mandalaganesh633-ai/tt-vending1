# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    # After reset, FSM should be in IDLE state
    # led_insert = 1, so seg_units should show 0 (0b0111111 = 0x3F)
    # total = 0 → display shows "00"
    dut._log.info("Checking initial state after reset")
    seg_units = dut.uo_out.value & 0x7F  # lower 7 bits
    assert seg_units == 0x3F, f"Expected seg for 0 (0x3F), got {hex(seg_units)}"
    dut._log.info("PASS: Display shows 0 after reset")

    # Insert a ₹5 coin: coin_type=10 (bits [2:1]), coin_valid=1 (bit [0])
    # ui_in = 0b00_00_10_1 = prod_sel=00, coin_type=10, coin_valid=1 = 0x05
    dut._log.info("Inserting ₹5 coin")
    dut.ui_in.value = 0x05  # coin_valid=1, coin_type=10
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0x00  # release coin_valid
    await ClockCycles(dut.clk, 5)

    # total should now be 5 → seg_units shows "5" = 0b1101101 = 0x6D
    seg_units = dut.uo_out.value & 0x7F
    assert seg_units == 0x6D, f"Expected seg for 5 (0x6D), got {hex(seg_units)}"
    dut._log.info("PASS: Display shows 5 after ₹5 coin")

    # Product A costs ₹5, total=5 → should auto-dispense
    # Wait for FSM to process (ACCEPT → DISPENSE → IDLE)
    await ClockCycles(dut.clk, 10)

    # After dispense + clear, total should be 0 again
    seg_units = dut.uo_out.value & 0x7F
    assert seg_units == 0x3F, f"Expected seg for 0 (0x3F) after dispense, got {hex(seg_units)}"
    dut._log.info("PASS: Display back to 0 after exact-change dispense")

    dut._log.info("All tests passed!")
