# 面向 FPGA 的低资源 QPSK 调制器

[English](README.md) | 中文

本仓库包含低资源 QPSK 调制器的 MATLAB 仿真核心与 Vivado FPGA 实现。项目重点是定点 QPSK 调制、SRRC 脉冲成形、数字中频生成，以及面向小型 Xilinx 器件的 FPGA 资源优化。

## 仓库结构

```text
.
├── fpga_code/       # Vivado RTL 工程、约束、脚本、报告和仿真 testbench
└── matlab_core/     # MATLAB 算法模型、定点实验、CSV 数据和图表
```

## 设计特点

- Gray 编码 QPSK 映射。
- SRRC 脉冲成形滤波器，参数为 `beta = 0.25`、`span = 8`、`sps = 4`。
- 12 bit 定点参考模型与 FPGA RTL 实现。
- 低资源 `Fs/4` 中频方案，用 I/Q 交换和符号翻转替代载波乘法。
- 默认 FPGA 构建采用对称 shift-add FIR，避免使用 DSP48。
- 保留 DDS 与 CORDIC 中频路径作为结构对比参考。

## MATLAB 仿真核心

`matlab_core/` 中的 MATLAB 模型用于验证算法正确性和定点精度。

在 MATLAB 中运行：

```matlab
cd matlab_core
run_all_qpsk_experiments
```

主要输出包括：

- `matlab_core/data/ber_evm_baseline.csv`
- `matlab_core/data/bitwidth_sweep.csv`
- `matlab_core/data/architecture_comparison.csv`
- `matlab_core/data/srrc_compression_results.csv`
- `matlab_core/figures/*.png`

12 bit 无噪声本征 RMS EVM 结果：

| 模式 | 本征 EVM |
|---|---:|
| BASEBAND | 0.3746% |
| FS4_IF | 0.5718% |
| DDS_IF | 0.5705% |
| CORDIC_IF | 0.5645% |

四种模式在无噪声本征调制器测试中均低于 5% 设计目标。

## FPGA 实现

`fpga_code/` 中的 Vivado 工程目标器件为 `xc7s6-1ftgb196` / Vivado part `xc7s6ftgb196-1`。

关键文件：

- `fpga_code/hdl/qpsk_top.sv`：顶层模块。
- `fpga_code/hdl/qpsk_tx_core_lowres.sv`：低资源发射机核心。
- `fpga_code/hdl/srrc_fir_complex_shiftadd.sv`：对称 shift-add SRRC FIR。
- `fpga_code/hdl/qpsk_tx_core.sv`：包含 BASEBAND、FS4_IF、DDS_IF、CORDIC_IF 的完整参考核心。
- `fpga_code/sim/tb_qpsk_tx_core.sv`：自检仿真 testbench。
- `fpga_code/constraints/design.xdc`：时钟约束和板级引脚占位约束。
- `fpga_code/scripts/*.tcl`：工程创建、综合和仿真脚本。

### 重建 Vivado 工程

```powershell
cd fpga_code
& "D:\Vivado\2025.2\Vivado\bin\vivado.bat" -mode batch -source scripts/01_create_project.tcl -log create_project.log -nojournal
```

### 运行仿真

```powershell
cd fpga_code
& "D:\Vivado\2025.2\Vivado\bin\vivado.bat" -mode batch -source scripts/03_run_sim.tcl -log run_sim.log -nojournal
```

期望仿真摘要：

```text
PASS: QPSK mapper, SRRC, LOW_RESOURCE FS4, BASEBAND, FS4_IF, DDS_IF and CORDIC_IF simulations completed.
```

### 运行综合

```powershell
cd fpga_code
& "D:\Vivado\2025.2\Vivado\bin\vivado.bat" -mode batch -source scripts/02_build_synth.tcl -log build_synth.log -nojournal
```

100 MHz 下最近一次低资源综合结果：

| 资源 | 使用量 |
|---|---:|
| Slice LUTs | 1802 / 3750 = 48.05% |
| Slice registers | 168 / 7500 = 2.24% |
| DSP48E1 | 0 / 10 = 0.00% |
| Block RAM tiles | 0 / 5 = 0.00% |
| Bonded IOB | 45 / 100 = 45.00% |
| WNS | 8.571 ns |
| TNS | 0.000 ns |

## 板级集成说明

`fpga_code/constraints/design.xdc` 当前包含 100 MHz 时钟约束和板级引脚占位项。在生成 bitstream 或上板前，需要为时钟、复位、输入数据、valid 信号和输出端口补充具体开发板的 `PACKAGE_PIN` 与 `IOSTANDARD` 约束。

如果开发板外部引脚较少，建议仅将 `y_if` 连接到主要外部接口，并通过内部 ILA 观察 `i_bb` / `q_bb`。

## 预期输出文件

- MATLAB CSV 数据和 PNG 图表：`matlab_core/data/`、`matlab_core/figures/`。
- Vivado 报告：`fpga_code/reports/`。
- 完成实现和板级约束后可生成 FPGA bitstream。

## 后续步骤

1. 补全板级 XDC 引脚约束。
2. 在 Vivado 中运行 implementation 并完成时序收敛。
3. 在 timing 和 DRC 检查通过后生成 bitstream。
4. 通过 DAC/PWM/debug capture 或 ILA 在硬件上验证调制输出。

## 许可证

当前尚未指定许可证。若需要公开分发或复用，请补充 license 文件。
