# Router-1x3-RTL-Design---Verilog

## Description
This repository contains a Verilog RTL implementation of a 1x3 Network-on-Chip (NoC) Router. It features an FSM-controlled routing mechanism, three independent 16-byte deep FIFOs, a packet synchronizer, and a data register block with built-in parity calculation and error checking. The design efficiently handles structured packet switching and error detection for digital networks.

## Features
*   **Packet Switching:** Routes incoming 8-bit flits to one of three output ports based on the 2-bit address embedded in the header.
*   **Internal FIFOs:** Three dedicated synchronous FIFOs, each capable of buffering 16 bytes of data.
*   **Synchronizer Module:** Decodes addresses, maps write enables to the correct FIFO, and signals output validity.
*   **Parity Error Checking:** Calculates parity across the header and payload during transmission, comparing it with the appended parity byte. Asserts an `err` flag upon mismatch.
*   **FSM Control Unit:** An 8-state Moore machine that coordinates data latching, flow control (`busy` signal), and packet error processing.

## Architecture & Module Hierarchy
*   `router_top`: The main wrapper that integrates all sub-modules.
    *   `router_fsm`: The finite state machine directing packet flow and state transitions.
    *   `router_reg`: The register block handling temporary storage, parity calculation, and error validation.
    *   `fifosyn`: The synchronizer managing control signals between the FSM and FIFOs.
    *   `fifos` (x3): 16x8-bit synchronous FIFOs for temporary buffering at the output ports.

## Packet Format
The router processes packets structured as follows:
1.  **Header Byte:** The lower 2 bits specify the destination address (00, 01, or 10). The upper 6 bits define the payload length (number of payload bytes).
2.  **Payload Bytes:** 8-bit data flits.
3.  **Parity Byte:** The XOR sum of the header and all payload bytes.

## Getting Started

### Prerequisites
*   A Verilog simulator (e.g., Xilinx Vivado, ModelSim, or Icarus Verilog).

### Simulation
1.  Add the RTL source file and `router_tb` to your simulation environment.
2.  Set `router_tb` as the top-level module.
3.  Run the simulation. The testbench automatically initializes the module, transmits a randomized packet with computed parity to port 0, and reads out the buffered data.
4.  Observe the waveform viewer to track control signals, FSM state changes, and the flow of data out of `data_out_0`.

---
**Author:** Shalem Raju Redapangu | RTL Design Engineer
