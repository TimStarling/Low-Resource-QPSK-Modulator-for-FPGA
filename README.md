# Low-Resource QPSK Modulator for FPGA

English | [中文](README_CN.md)

This repository contains the MATLAB simulation core and Vivado FPGA implementation for a low-resource QPSK modulator. The project focuses on fixed-point QPSK modulation, SRRC pulse shaping, digital IF generation, and FPGA resource reduction for small Xilinx devices.

## Repository Layout

```text
.
├── fpga_code/       # Vivado RTL project, constraints, scripts, reports, and simulation testbench
└── matlab_core/     # MATLAB algorithm model, fixed-point experiments, CSV data, and figures
```

## Design Highlights

- Gray-coded QPSK mapper.
- SRRC pulse-shaping filter with `beta = 0.25`, `span = 8`, and `sps = 4`.
- 12-bit fixed-point reference model and FPGA-oriented RTL.
- Low-resource `Fs/4` IF path that replaces carrier multiplication with I/Q swapping and sign inversion.
- Shift-add symmetric FIR implementation that avoids DSP48 usage in the default FPGA build.
- Reference DDS and CORDIC IF paths for architectural comparison.

## MATLAB Core

The MATLAB model in `matlab_core/` verifies algorithm correctness and fixed-point behavior.

Run from MATLAB:

```matlab
cd matlab_core
run_all_qpsk_experiments
```

Main generated outputs include:

- `matlab_core/data/ber_evm_baseline.csv`
- `matlab_core/data/bitwidth_sweep.csv`
- `matlab_core/data/architecture_comparison.csv`
- `matlab_core/data/srrc_compression_results.csv`
- `matlab_core/figures/*.png`

Key intrinsic 12-bit RMS EVM results:

| Mode | Intrinsic EVM |
|---|---:|
| BASEBAND | 0.3746% |
| FS4_IF | 0.5718% |
| DDS_IF | 0.5705% |
| CORDIC_IF | 0.5645% |

All modes are below the 5% design target in the noiseless intrinsic modulator test.

## FPGA Implementation

The Vivado project in `fpga_code/` targets `xc7s6-1ftgb196` / Vivado part `xc7s6ftgb196-1`.

Important files:

- `fpga_code/hdl/qpsk_top.sv`: top-level module.
- `fpga_code/hdl/qpsk_tx_core_lowres.sv`: low-resource transmitter core.
- `fpga_code/hdl/srrc_fir_complex_shiftadd.sv`: symmetric shift-add SRRC FIR.
- `fpga_code/hdl/qpsk_tx_core.sv`: full reference core with BASEBAND, FS4_IF, DDS_IF, and CORDIC_IF modes.
- `fpga_code/sim/tb_qpsk_tx_core.sv`: self-checking simulation testbench.
- `fpga_code/constraints/design.xdc`: clock constraint and board-pin placeholders.
- `fpga_code/scripts/*.tcl`: project creation, synthesis, and simulation scripts.

### Recreate Vivado Project

```powershell
cd fpga_code
& "D:\Vivado\2025.2\Vivado\bin\vivado.bat" -mode batch -source scripts/01_create_project.tcl -log create_project.log -nojournal
```

### Run Simulation

```powershell
cd fpga_code
& "D:\Vivado\2025.2\Vivado\bin\vivado.bat" -mode batch -source scripts/03_run_sim.tcl -log run_sim.log -nojournal
```

Expected simulation summary:

```text
PASS: QPSK mapper, SRRC, LOW_RESOURCE FS4, BASEBAND, FS4_IF, DDS_IF and CORDIC_IF simulations completed.
```

### Run Synthesis

```powershell
cd fpga_code
& "D:\Vivado\2025.2\Vivado\bin\vivado.bat" -mode batch -source scripts/02_build_synth.tcl -log build_synth.log -nojournal
```

Latest low-resource synthesis result at 100 MHz:

| Resource | Usage |
|---|---:|
| Slice LUTs | 1802 / 3750 = 48.05% |
| Slice registers | 168 / 7500 = 2.24% |
| DSP48E1 | 0 / 10 = 0.00% |
| Block RAM tiles | 0 / 5 = 0.00% |
| Bonded IOB | 45 / 100 = 45.00% |
| WNS | 8.571 ns |
| TNS | 0.000 ns |

## Board Integration Notes

`fpga_code/constraints/design.xdc` currently contains the 100 MHz clock constraint and board-pin placeholders. Before bitstream generation or board programming, assign board-specific `PACKAGE_PIN` and `IOSTANDARD` constraints for the clock, reset, input data, valid signals, and output ports.

If the board has limited external pins, route only `y_if` to the primary external interface and observe `i_bb` / `q_bb` through an internal ILA.

## Expected Output Files

- MATLAB CSV data and PNG figures under `matlab_core/data/` and `matlab_core/figures/`.
- Vivado reports under `fpga_code/reports/`.
- Optional FPGA bitstream after implementation and board-specific constraints are completed.

## Next Steps

1. Complete board-specific XDC pin constraints.
2. Run implementation and timing closure in Vivado.
3. Generate the bitstream after timing and DRC checks pass.
4. Validate the modulated output on hardware with DAC/PWM/debug capture or ILA.

## Citation and License

If you use this project code, data, figures, or implementation ideas in a paper, report, thesis, or other publication, please clearly acknowledge this repository and describe the reused parts in the manuscript.

Any use, redistribution, or derivative work must also comply with the corresponding open-source license terms of this repository and all third-party tools or dependencies used with it.
