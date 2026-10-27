# AXI-LiteBurst-32
### Configurable AXI4-Lite-Compatible Slave Interface with Burst Support and Low-Power Design

## 1. Project Overview

**AXI-LiteBurst-32** is a Verilog-based RTL design project developed using AMD Xilinx Vivado. It aims to implement a 32-bit memory-mapped slave interface supporting single data transfers and short burst transactions of up to 16 beats, along with low-power design considerations.

The design explores AXI communication concepts, finite state machines (FSMs), address decoding, register-based storage, handshake mechanisms, and RTL verification.

**Important protocol note:** Standard AXI4-Lite supports single-beat transactions and does not support bursts. This project therefore explores a custom burst-capable extension of an AXI4-Lite-style interface rather than claiming full standard AXI4-Lite compliance.

## 2. Objectives

- Design a 32-bit memory-mapped slave interface using Verilog HDL.
- Support single read and write transactions.
- Develop burst transaction handling for up to 16 beats.
- Implement address decoding for register selection.
- Manage transaction control using finite state machines.
- Handle valid/ready handshakes and response signaling.
- Explore low-power techniques, such as reducing unnecessary switching activity.
- Verify functionality through simulation in Vivado.

## 3. Key Features

| Feature | Description |
|---|---|
| Data width | 32 bits |
| Address width | Configurable, depending on RTL implementation |
| Transfer types | Single transfers and custom burst transfers |
| Maximum burst length | Up to 16 beats, if implemented |
| Interface | Memory-mapped slave interface |
| RTL language | Verilog HDL |
| Development tool | AMD Xilinx Vivado |
| Verification | RTL testbench and waveform analysis |
| Low-power design | Design objective; implementation to be verified |

## 4. System Architecture

The intended architecture consists of the following functional blocks:

1. **Address Decoder:** Selects the target register or memory-mapped location based on the incoming address.
2. **Write Controller:** Coordinates write address acceptance, write data reception, and write responses.
3. **Read Controller:** Handles read requests and returns the requested data.
4. **Burst Controller:** Tracks the number of beats and manages burst progression.
5. **Register Bank:** Stores configuration values or transaction data.
6. **Finite State Machine:** Controls the transaction sequence and handshake behavior.
7. **Response Logic:** Generates the appropriate completion and error responses.
8. **Low-Power Logic:** Reduces unnecessary internal activity where supported by the implementation.

### Simplified Block Diagram

```text
             AXI-Compatible Master
                      |
                      v
          +-----------------------+
          | Handshake Interface   |
          +-----------------------+
                      |
          +-----------+-----------+
          |                       |
          v                       v
 +----------------+      +----------------+
 | Write Control  |      | Read Control   |
 +----------------+      +----------------+
          |                       |
          +-----------+-----------+
                      |
                      v
          +-----------------------+
          | Burst / FSM Control   |
          +-----------------------+
                      |
                      v
          +-----------------------+
          | Address Decoder       |
          +-----------------------+
                      |
                      v
          +-----------------------+
          | 32-bit Register Bank  |
          +-----------------------+
                      |
                      v
          +-----------------------+
          | Response Generation   |
          +-----------------------+
```

*The diagram represents the intended architecture. Actual block boundaries may differ in the RTL.*

## 5. AXI Handshake Fundamentals

The AXI memory-mapped protocol uses independent channels for address, data, and responses.

For an AXI4-style interface, the principal channels are:

- **AW:** Write address channel.
- **W:** Write data channel.
- **B:** Write response channel.
- **AR:** Read address channel.
- **R:** Read data channel.

The `VALID` and `READY` signals coordinate transfers. A transfer occurs when both signals are asserted on the same clock edge.

For example:

```verilog
if (VALID && READY) begin
    // Transfer accepted
end
```

This is a conceptual example, not a complete AXI controller.

For burst-capable AXI4 transactions, burst length, burst type, transfer size, and last-beat handling must also be managed. The custom burst extension must define how these properties are represented and validated.

## 6. Burst Transaction Concept

A burst transaction transfers multiple data beats as part of one transaction.

For a 32-bit data bus:

- Data per beat: 4 bytes.
- Maximum intended burst length: 16 beats.
- Total data per maximum-length burst: 64 bytes.

The total assumes 16 full-width beats and excludes any additional protocol overhead.

The burst controller must track the accepted beats, update addresses according to the configured burst mode, and identify the final beat. For an AXI4-style write burst, `WLAST` identifies the final write-data beat; `RLAST` identifies the final read-data beat.

## 7. Tools and Technologies

- **AMD Xilinx Vivado Design Suite:** RTL development, simulation, synthesis, and implementation.
- **Verilog HDL:** Hardware description and RTL design.
- **Vivado Simulator (XSim):** Functional verification and waveform inspection.
- **FPGA hardware:** Optional deployment target, depending on the selected device and constraints.

## 8. Repository Structure

A recommended repository structure is:

```text
AXI-LiteBurst-32/
|
+-- README.md
|
+-- rtl/
|   +-- axi_liteburst_32.v
|   +-- address_decoder.v
|   +-- burst_controller.v
|   +-- register_bank.v
|
+-- sim/
|   +-- tb_axi_liteburst_32.v
|
+-- constraints/
|   +-- design.xdc
|
+-- docs/
|   +-- architecture.png
|   +-- simulation_waveforms.png
|
+-- reports/
|   +-- synthesis_summary.md
|
+-- vivado/
    +-- project_setup.md
```

This is a suggested structure. Keep only files that actually exist in your project and update the module names to match your RTL.

## 9. How to Open the Project in Vivado

1. Install and launch AMD Xilinx Vivado.
2. Open the existing project using **File → Project → Open** and select the `.xpr` file.
3. If starting from source files, create a new RTL project and add the Verilog files under Design Sources.
4. Add the testbench under Simulation Sources.
5. Select the correct top-level module.
6. Check for syntax errors and elaborate the design.
7. Run behavioral simulation.
8. Inspect the waveform for reset behavior, handshake timing, read/write operations, and burst completion.
9. Run synthesis and implementation when the design and target constraints are ready.

## 10. Verification Plan

The following tests should be included in the testbench:

| Test case | Expected behavior |
|---|---|
| Reset | Controller and registers enter their defined reset states |
| Single write | Data is written to the selected location |
| Single read | Correct data is returned |
| Back-to-back transactions | Successive requests are handled correctly |
| Burst write | All accepted write beats are stored correctly |
| Burst read | All requested beats are returned correctly |
| Maximum burst | A 16-beat transaction completes correctly |
| Backpressure | Transactions remain correct when `READY` is delayed |
| Invalid address | Defined error or default-register behavior occurs |
| Reset during activity | Behavior matches the documented reset policy |

These are planned verification cases, not a claim that every case has already passed.

## 11. Low-Power Considerations

Possible low-power techniques include:

- Clock enables for register updates.
- Avoiding unnecessary register changes.
- Reducing redundant switching in control logic.
- Using appropriate clocking and reset strategies.
- Comparing synthesis and power-estimation reports before and after optimization.

Power improvements should be confirmed using implementation-specific reports rather than assumed from RTL structure alone.

## 12. Results and Performance

Record the following after running the project in Vivado:

- Target FPGA device.
- Synthesis status.
- LUT and flip-flop utilization.
- Maximum achieved clock frequency or timing slack.
- Simulation test results.
- Estimated dynamic and static power, if available.

Do not report performance figures until they have been measured from the actual design.

## 13. Current Status

**Project status:** RTL development and verification status to be updated.

Update this section when you have confirmed:

- [ ] Single read and write transactions.
- [ ] Burst transactions up to 16 beats.
- [ ] Correct handshake and response behavior.
- [ ] Reset and backpressure test cases.
- [ ] Successful behavioral simulation.
- [ ] Successful synthesis.
- [ ] Timing and resource analysis.
- [ ] Low-power evaluation.

## 14. Learning Outcomes

This project provides practical experience with:

- AMBA AXI protocol fundamentals.
- Memory-mapped hardware interfaces.
- Verilog RTL design.
- Finite state machine design.
- Address decoding and register mapping.
- Burst transaction control.
- Testbench development and waveform debugging.
- FPGA synthesis and implementation workflows.

## 15. References

1. AMD, [Vivado Design Suite AXI Reference Guide (UG1037)](https://www.amd.com/content/dam/xilinx/support/documents/ip_documentation/axi_ref_guide/latest/ug1037-vivado-axi-reference-guide.pdf).
2. AMD, [Vivado Design Suite User Guide: Logic Simulation (UG900)](https://docs.amd.com/r/2024.1-English/ug900-vivado-logic-simulation).
3. AMD, [AMBA AXI4 Interface Protocol Resources](https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/axi.html).

---

**AXI-LiteBurst-32 — RTL Design, Verification, and Low-Power Exploration**

Developed using Verilog HDL and AMD Xilinx Vivado.
