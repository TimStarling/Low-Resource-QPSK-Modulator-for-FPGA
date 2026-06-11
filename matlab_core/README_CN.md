# 低资源 QPSK 调制器 MATLAB 仿真核心

本目录存放“低资源 QPSK 调制器研究与实现报告”的 MATLAB 仿真代码、实验数据和图表。

## 当前结论

可以有底气地说：

**MATLAB 仿真结果已达到报告中算法验证、定点分析和低资源结构对比的目标。**

但这个结论仅限于 MATLAB 仿真阶段。Vivado 综合、post-route 资源报告、Fmax、功耗分析、关键路径分析和板级验证尚未完成，因此还不能说整个“研究与实现报告”已经全部完成。

## 已实现实验

1. BER/EVM 基线实验：
   - QPSK Gray 映射；
   - SRRC 脉冲成形，参数为 `beta = 0.25`、`span = 8`、`sps = 4`；
   - AWGN 信道；
   - 基于前导的采样相位搜索和公共相位校正；
   - 浮点模型与 12 bit 定点模型对比；
   - BER 基线使用 `50000` 个负载符号，提高统计稳定性。

2. 定点位宽扫描实验：
   - 数据和滤波器系数位宽扫描：8、10、12、14、16 bit；
   - 在 8、10、12、14 dB 下统计 BER 和 RMS EVM；
   - 同时附带资源估算，便于生成论文表格。

3. 调制器本征 EVM 实验：
   - 使用无噪声链路，把调制器实现误差与 AWGN 信道误差分离；
   - 对 `BASEBAND`、`FS4_IF`、`DDS_IF`、`CORDIC_IF` 四种结构进行位宽扫描；
   - 这是判断“调制器本身是否达到 EVM 目标”的主要依据。

4. 结构对比实验：
   - `BASEBAND`：复基带 I/Q 输出；
   - `FS4_IF`：`Fs/4` 无乘法实中频输出；
   - `DDS_IF`：四分之一波 LUT/DDS 载波；
   - `CORDIC_IF`：有限迭代 CORDIC 载波。

5. 面向论文的资源估算：
   - 输出 LUT、FF、BRAM、DSP、Fmax 和延迟估算；
   - 当前数值是 MATLAB 仿真侧估算，不是 Vivado 综合实测结果。

6. 资源-性能综合评分与自动配置选择：
   - 综合评分同时考虑本征 EVM、LUT、FF、DSP 和延迟；
   - 先筛选满足 `1%` 本征 EVM 约束的配置；
   - 自动搜索结果显示，综合评分最优配置为 `BASEBAND 10 bit`，本征 EVM 为 `0.4381%`，资源估算为 `680 LUT / 900 FF`，综合评分为 `0.0955`。

7. SRRC 滤波器压缩对比：
   - 对比 17 taps、25 taps 和 33 taps 三种 SRRC 成形滤波器；
   - 17 taps 资源最低，但本征 EVM 超过 5% 目标；
   - 25 taps 本征 EVM 低于 5%，可作为资源受限场景下的工程折中方案；
   - 33 taps 本征 EVM 低于 1%，仍是高精度推荐配置。

## 关键结果

12 bit 无噪声本征 RMS EVM 结果如下：

| 模式 | 本征 EVM |
|---|---:|
| BASEBAND | 0.3746% |
| FS4_IF | 0.5718% |
| DDS_IF | 0.5705% |
| CORDIC_IF | 0.5645% |

四种模式均低于报告建议的 `5%` RMS EVM 目标。

12 dB Eb/N0 下的含噪声结构对比结果如下：

| 模式 | BER | 含噪声 EVM | LUT 估算 | FF 估算 |
|---|---:|---:|---:|---:|
| BASEBAND | 0 | 17.6655% | 764 | 1016 |
| FS4_IF | 0 | 25.2397% | 854 | 1126 |
| DDS_IF | 0.0001 | 25.2142% | 994 | 1246 |
| CORDIC_IF | 0 | 23.8443% | 1124 | 1446 |

注意：含噪声 EVM 包含 AWGN 信道和接收链路影响，不能直接作为调制器本身精度。判断调制器精度时，应使用上面的“本征 EVM”结果。

在 `1%` 本征 EVM 约束下，自动优化结果如下：

| 选择准则 | 模式 | 位宽 | 本征 EVM | LUT | FF | 综合评分 |
|---|---|---:|---:|---:|---:|---:|
| 综合评分最优 | BASEBAND | 10 | 0.4381% | 680 | 900 | 0.0955 |
| 满足 1% EVM 的最低 LUT | BASEBAND | 8 | 0.7769% | 596 | 784 | 0.1716 |
| 满足 1% EVM 的最低 EVM | BASEBAND | 16 | 0.3371% | 932 | 1248 | 0.3245 |

SRRC 压缩实验表明，25 taps 是一个有价值的低资源折中点：BASEBAND 25 taps 的本征 EVM 为 `3.8730%`，估算资源为 `622 LUT`；FS4_IF 25 taps 的本征 EVM 为 `3.9959%`，估算资源为 `691 LUT`。二者均低于 5% EVM 目标，同时比 33 taps 基线节省资源。

## 可直接写入论文的表述

下面这段可以直接写入报告的 MATLAB 仿真结果分析部分：

> MATLAB 仿真结果表明，所设计的低资源 QPSK 调制器在浮点与定点模型下均能正确完成 Gray 映射、SRRC 成形、数字中频调制及 AWGN 信道验证。BER 曲线与理论 QPSK-AWGN 曲线基本一致；在无噪声本征误差测试中，12 bit 定点 BASEBAND、FS4_IF、DDS_IF 和 CORDIC_IF 模式的 RMS EVM 分别为 0.3746%、0.5718%、0.5705% 和 0.5645%，均低于 5% 的设计目标。因此，MATLAB 仿真阶段已达到报告设定的算法正确性、定点精度和结构对比目标。

如果要强调低资源结构优势，可以补充：

> 在结构对比中，FS4_IF 模式通过选择 `Fs/4` 固定中频，将传统正交上变频中的乘法运算简化为符号翻转和 I/Q 交换。在 12 bit 定点配置下，FS4_IF 模式的本征 EVM 为 0.5718%，仍显著低于 5% 目标；其资源估算为 854 LUT、1126 FF、1 BRAM 和 1 DSP，低于 DDS_IF 和 CORDIC_IF 两种可调载波方案。因此，FS4_IF 结构适合作为本文低资源 QPSK 调制器的主实现方案。

新增优化实验可以这样写：

> 为进一步量化低资源设计中的性能-资源折中，本文引入资源-性能综合评分指标，将本征 EVM、LUT、FF、DSP 和延迟统一归一化加权评价。在 `1%` 本征 EVM 约束下，自动搜索结果选择 10 bit BASEBAND 配置作为综合评分最优方案，其本征 EVM 为 0.4381%，资源估算为 680 LUT 和 900 FF。针对脉冲成形滤波器资源瓶颈，本文进一步比较 17 taps、25 taps 和 33 taps SRRC 结构。结果表明，17 taps 虽然资源最低，但本征 EVM 超过 5% 目标；25 taps 可将本征 EVM 控制在 5% 以内，同时相比 33 taps 明显降低资源占用；33 taps 则可将本征 EVM 降至 1% 以下，适合作为高精度工作模式。因此，本文形成了“33 taps 高精度模式 + 25 taps 低资源模式”的可配置滤波器优化策略。

## 参考文献依据

`../参考文献` 中的 10 篇 PDF 用于确定仿真范围和结构对比对象：

- Sakran 等 2025 年 QPSK DDS 论文：支持小型 LUT、相位累加器和低成本 DDS 对比；
- Al-Safi 2024 年 CORDIC QPSK 论文：支持 CORDIC 载波作为低 ROM 对照组；
- Tchendjeu 和 Tchitnga 2025 年 JECE 论文：支持非 DDS/非 CORDIC 振荡器和无存储载波思路；
- Al Zubaidy 等 2023 年 JESTEC 论文：支持共享 LUT、多模式调制、资源表和 Fmax 书写方式；
- Nataraj Urs 等 2023 年 TEMSMET 论文：支持 CORDIC/DPLL 数字调制背景；
- Jothimani 等 2023 年 DDS 调制论文：支持 DDS 作为多种数字调制的通用载波源；
- Seelam 等 2024 年卫星遥测论文：支持 DDS 子载波和工程发射链组织；
- Xing 等 2024 年 RT DDFS 论文：支持 ROM-less 递推三角 DDFS 作为扩展方向；
- Xing 等 2025 年 HRT DDFS 论文：支持无需 ROM 和迭代 CORDIC 的混合递推校正思路；
- 重复的 QPSK DDS PDF 与 Sakran 论文相同，作为重复文献处理。

## 输出文件

运行：

```matlab
run_all_qpsk_experiments
```

生成数据：

- `data/ber_evm_baseline.csv`
- `data/bitwidth_sweep.csv`
- `data/mode_comparison.csv`
- `data/intrinsic_evm.csv`
- `data/srrc_filter_comparison.csv`
- `data/resource_quality_score.csv`
- `data/optimization_summary.csv`
- `data/resource_estimate.csv`
- `data/qpsk_experiment_results.mat`

生成图表：

- `figures/ber_baseline.png`
- `figures/evm_vs_bitwidth.png`
- `figures/mode_comparison.png`
- `figures/intrinsic_evm.png`
- `figures/srrc_filter_comparison.png`
- `figures/resource_quality_score.png`
- `figures/resource_estimate.png`
- `figures/constellation_fs4_12db.png`

## 后续工作

最终提交前，应使用 Vivado 综合和实现报告替换当前资源估算值，并补充 post-route Fmax、功耗、关键路径和板级验证结果。
