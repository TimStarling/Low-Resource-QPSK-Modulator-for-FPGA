# fpga_code Vivado Project

Target device: `xc7s6-1ftgb196` / Vivado internal part `xc7s6ftgb196-1`

This directory contains the FPGA implementation of the low-resource QPSK transmitter derived from the MATLAB model in `../matlab_core` and the project report.

## Implemented Architecture

- QPSK Gray mapper, amplitude `1448`, matching the 12-bit fixed-point MATLAB model.
- 33-tap SRRC pulse shaping filter, `beta=0.25`, `span=8`, `sps=4`, Q11 coefficients.
- Default synthesizable top uses the low-resource `FS/4` IF path.
- Full reference RTL keeps `BASEBAND`, `FS4_IF`, `DDS_IF`, and `CORDIC_IF` modes for comparison and simulation.
- Low-resource FIR uses coefficient symmetry and shift-add constant multiplication, avoiding DSP48 usage.

## Important Files

- `hdl/qpsk_top.sv`: top module. Default parameter `LOW_RESOURCE=1` selects the low-resource FS/4 implementation.
- `hdl/qpsk_tx_core_lowres.sv`: low-resource QPSK transmitter core.
- `hdl/srrc_fir_complex_shiftadd.sv`: symmetric shift-add SRRC FIR, no DSP multiplier.
- `hdl/qpsk_tx_core.sv`: full reference transmitter with baseband, FS/4, DDS, and CORDIC IF modes.
- `hdl/srrc_fir_complex.sv`: direct constant-multiply SRRC reference FIR.
- `hdl/dds_carrier.sv`, `hdl/cordic_carrier.sv`, `hdl/qpsk_if_mixer.sv`: reference carrier/mixer paths.
- `sim/tb_qpsk_tx_core.sv`: self-checking simulation testbench.
- `constraints/design.xdc`: 100 MHz clock constraint plus board-pin placeholders.
- `scripts/01_create_project.tcl`: creates the Vivado project.
- `scripts/02_build_synth.tcl`: runs synthesis and writes reports.
- `scripts/03_run_sim.tcl`: runs behavioral simulation.

## Rebuild Project

```powershell
& "D:\Vivado\2025.2\Vivado\bin\vivado.bat" -mode batch -source scripts/01_create_project.tcl -log create_project.log -nojournal
```

## Run Simulation

```powershell
& "D:\Vivado\2025.2\Vivado\bin\vivado.bat" -mode batch -source scripts/03_run_sim.tcl -log run_sim.log -nojournal
```

Latest result:

```text
PASS: QPSK mapper, SRRC, LOW_RESOURCE FS4, BASEBAND, FS4_IF, DDS_IF and CORDIC_IF simulations completed.
```

The testbench checks:

- QPSK Gray mapping truth table.
- SRRC filtered baseband output is non-zero and valid.
- FS/4 IF output follows `I, -Q, -I, Q`.
- Low-resource top output is sample-by-sample identical to the full FS/4 reference path.
- DDS and CORDIC reference IF paths produce valid non-zero output.

## Run Synthesis

```powershell
& "D:\Vivado\2025.2\Vivado\bin\vivado.bat" -mode batch -source scripts/02_build_synth.tcl -log build_synth.log -nojournal
```

Latest low-resource synthesis result at 100 MHz:

- Slice LUTs: `1802 / 3750` = `48.05%`
- Slice registers: `168 / 7500` = `2.24%`
- DSP48E1: `0 / 10` = `0.00%`
- Block RAM tiles: `0 / 5` = `0.00%`
- Bonded IOB: `45 / 100` = `45.00%`
- WNS: `8.571 ns`
- TNS: `0.000 ns`

The earlier full multi-mode reference build used `2866 / 3750` LUTs and `10 / 10` DSPs. Therefore the default low-resource implementation is the recommended FPGA build for XC7S6.

## Board Integration Notes

`constraints/design.xdc` currently defines the 100 MHz clock only. Before bitstream generation, fill in board-specific `PACKAGE_PIN` and `IOSTANDARD` constraints for:

- `clk`
- `rst_n`
- `sample_en`
- `symbol_valid`
- `bits_in[1:0]`
- `i_bb[11:0]`
- `q_bb[11:0]`
- `y_if[13:0]`
- `out_valid`

If the board exposes fewer pins, keep `y_if` as the primary DAC/PWM/debug output and route `i_bb/q_bb` through an internal ILA instead of external pins.
