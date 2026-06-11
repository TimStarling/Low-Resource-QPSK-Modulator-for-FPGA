# Low-Resource QPSK MATLAB Core

This folder contains the MATLAB simulation core for the low-resource QPSK modulator research and implementation report.

## Status

The MATLAB simulation stage has reached the report targets for algorithm verification, fixed-point accuracy analysis, and low-resource architecture comparison.

This statement is limited to the MATLAB simulation stage. Vivado synthesis, post-route resource reports, Fmax, power analysis, critical path analysis, and board-level validation still need to be completed before claiming that the whole implementation report is finished.

## Implemented Experiments

1. BER/EVM baseline:
   - Gray-coded QPSK mapping.
   - SRRC pulse shaping with `beta = 0.25`, `span = 8`, `sps = 4`.
   - AWGN channel.
   - Preamble-based timing phase search and common phase correction.
   - Floating-point and 12-bit fixed-point comparison.
   - BER baseline uses `50000` payload symbols for more stable statistics.

2. Fixed-point bit-width sweep:
   - Data/coefficient widths: 8, 10, 12, 14, and 16 bits.
   - BER and RMS EVM are measured at 8, 10, 12, and 14 dB.
   - Resource estimates are attached to each width for report tables.

3. Intrinsic modulator EVM:
   - Noiseless simulation separates implementation error from AWGN channel error.
   - `BASEBAND`, `FS4_IF`, `DDS_IF`, and `CORDIC_IF` are swept over 8, 10, 12, 14, and 16 bits.
   - This is the primary EVM evidence for whether the modulator itself meets the report target.

4. Architecture comparison:
   - `BASEBAND`: complex I/Q output.
   - `FS4_IF`: multiplier-free real IF output at `Fs/4`.
   - `DDS_IF`: quarter-wave LUT/DDS carrier.
   - `CORDIC_IF`: finite-iteration CORDIC carrier.

5. Report-oriented resource estimate:
   - LUT, FF, BRAM, DSP, Fmax, and latency estimates are generated for report tables.
   - These are simulation-side estimates, not Vivado post-synthesis numbers.

6. Resource-quality scoring and automatic configuration selection:
   - A weighted score combines intrinsic EVM, LUT, FF, DSP, and latency.
   - Configurations are filtered by the `1%` intrinsic EVM target.
   - The best weighted configuration is `BASEBAND 10-bit`, with intrinsic EVM `0.4381%`, estimated `680 LUT / 900 FF`, and score `0.0955`.

7. SRRC filter compression comparison:
   - 17-tap, 25-tap, and 33-tap SRRC filters are compared.
   - The 17-tap version saves resources but exceeds the 5% intrinsic EVM target.
   - The 25-tap version stays below 5% EVM and can be used as a resource-saving engineering option.
   - The 33-tap version stays below 1% EVM and remains the recommended high-accuracy configuration.

## Key Results

The 12-bit noiseless intrinsic RMS EVM results are:

| Mode | Intrinsic EVM |
|---|---:|
| BASEBAND | 0.3746% |
| FS4_IF | 0.5718% |
| DDS_IF | 0.5705% |
| CORDIC_IF | 0.5645% |

All four modes are below the report target of 5% RMS EVM.

At 12 dB Eb/N0, the noisy channel-mode comparison gives:

| Mode | BER | Channel EVM | LUT estimate | FF estimate |
|---|---:|---:|---:|---:|
| BASEBAND | 0 | 17.6655% | 764 | 1016 |
| FS4_IF | 0 | 25.2397% | 854 | 1126 |
| DDS_IF | 0.0001 | 25.2142% | 994 | 1246 |
| CORDIC_IF | 0 | 23.8443% | 1124 | 1446 |

The noisy EVM values include AWGN and receiver-chain effects, so they should not be used as the intrinsic modulator accuracy. The intrinsic EVM table above is the correct evidence for modulator precision.

The automatic optimization results under the 1% intrinsic EVM constraint are:

| Criterion | Mode | Width | Intrinsic EVM | LUT | FF | Score |
|---|---|---:|---:|---:|---:|---:|
| Best weighted score | BASEBAND | 10 | 0.4381% | 680 | 900 | 0.0955 |
| Lowest LUT under 1% EVM | BASEBAND | 8 | 0.7769% | 596 | 784 | 0.1716 |
| Lowest EVM under 1% EVM | BASEBAND | 16 | 0.3371% | 932 | 1248 | 0.3245 |

The SRRC compression result shows that 25 taps provide a practical low-resource compromise: BASEBAND 25-tap intrinsic EVM is `3.8730%` with estimated `622 LUT`, while FS4_IF 25-tap intrinsic EVM is `3.9959%` with estimated `691 LUT`.

## Paper-Ready Statement

The following paragraph can be used in the report:

> MATLAB simulation results show that the proposed low-resource QPSK modulator correctly implements Gray mapping, SRRC pulse shaping, digital IF modulation, and AWGN channel verification in both floating-point and fixed-point models. The simulated BER curve is generally consistent with the theoretical QPSK-AWGN BER curve. In the noiseless intrinsic-error test, the 12-bit fixed-point RMS EVM values of the BASEBAND, FS4_IF, DDS_IF, and CORDIC_IF modes are 0.3746%, 0.5718%, 0.5705%, and 0.5645%, respectively, all below the 5% design target. Therefore, the MATLAB simulation stage satisfies the report targets for algorithm correctness, fixed-point precision, and architecture comparison.

Additional optimization statement:

> To further quantify the low-resource design trade-off, a resource-quality score was introduced by jointly weighting intrinsic EVM, LUT, FF, DSP, and latency. Under the 1% intrinsic EVM constraint, the automatic search selected the 10-bit BASEBAND configuration as the best weighted solution, with 0.4381% intrinsic EVM and estimated 680 LUT / 900 FF. For pulse-shaping resource reduction, the SRRC span was swept from 4 to 8 symbols. The 17-tap filter reduced LUT usage but exceeded the 5% EVM target, while the 25-tap filter kept the intrinsic EVM below 5% with lower resource usage than the 33-tap baseline. These results support a configurable implementation strategy: 33 taps for high-accuracy operation and 25 taps for resource-constrained operation.

## Reference Basis

The 10 PDFs in the reference folder were used to define the simulation scope:

- Sakran et al. 2025 QPSK DDS paper: supports small LUT, phase accumulator, and low-cost DDS comparison.
- Al-Safi 2024 CORDIC QPSK paper: supports CORDIC carrier generation as the low-ROM control group.
- Tchendjeu and Tchitnga 2025 JECE paper: supports non-DDS/non-CORDIC oscillator discussion and no-memory carrier motivation.
- Al Zubaidy et al. 2023 JESTEC paper: supports shared LUT, multi-mode modulation, resource table style, and Fmax reporting.
- Nataraj Urs et al. 2023 TEMSMET paper: supports CORDIC/DPLL digital modulation context.
- Jothimani et al. 2023 DDS modulation paper: supports DDS as a reusable carrier source for multiple digital modulations.
- Seelam et al. 2024 satellite telemetry paper: supports DDS-based sub-carrier and engineering transmitter organization.
- Xing et al. 2024 RT DDFS paper: supports ROM-less recursive trigonometric DDFS as an advanced alternative.
- Xing et al. 2025 HRT DDFS paper: supports hybrid recursive correction without ROM or iterative CORDIC.
- The duplicated QPSK DDS PDF confirms the same Sakran DDS baseline and is treated as a duplicate reference.

## Outputs

Run:

```matlab
run_all_qpsk_experiments
```

Generated data:

- `data/ber_evm_baseline.csv`
- `data/bitwidth_sweep.csv`
- `data/mode_comparison.csv`
- `data/intrinsic_evm.csv`
- `data/srrc_filter_comparison.csv`
- `data/resource_quality_score.csv`
- `data/optimization_summary.csv`
- `data/resource_estimate.csv`
- `data/qpsk_experiment_results.mat`

Generated figures:

- `figures/ber_baseline.png`
- `figures/evm_vs_bitwidth.png`
- `figures/mode_comparison.png`
- `figures/intrinsic_evm.png`
- `figures/srrc_filter_comparison.png`
- `figures/resource_quality_score.png`
- `figures/resource_estimate.png`
- `figures/constellation_fs4_12db.png`

## Next Step

Replace the analytical resource estimates with Vivado synthesis and implementation results before final submission.
