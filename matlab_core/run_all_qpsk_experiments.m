clear; clc; close all;

rootDir = fileparts(mfilename("fullpath"));
dataDir = fullfile(rootDir, "data");
figDir = fullfile(rootDir, "figures");
if ~exist(dataDir, "dir"), mkdir(dataDir); end
if ~exist(figDir, "dir"), mkdir(figDir); end

rng(20260604, "twister");

p = default_params();
fprintf("Low-resource QPSK simulation started: %s\n", string(datetime("now")));
fprintf("Nsym=%d, sps=%d, beta=%.2f, span=%d, Eb/N0=%s dB\n", ...
    p.Nsym, p.sps, p.beta, p.span, mat2str(p.EbN0dB));

berResults = run_ber_evm_experiment(p);
writetable(berResults, fullfile(dataDir, "ber_evm_baseline.csv"));

bitwidthResults = run_bitwidth_sweep(p);
writetable(bitwidthResults, fullfile(dataDir, "bitwidth_sweep.csv"));

modeResults = run_mode_comparison(p);
writetable(modeResults, fullfile(dataDir, "mode_comparison.csv"));

intrinsicResults = run_intrinsic_evm_experiment(p);
writetable(intrinsicResults, fullfile(dataDir, "intrinsic_evm.csv"));

srrcResults = run_srrc_filter_comparison(p);
writetable(srrcResults, fullfile(dataDir, "srrc_filter_comparison.csv"));

resourceResults = resource_estimate_table();
writetable(resourceResults, fullfile(dataDir, "resource_estimate.csv"));

qualityResults = run_resource_quality_scoring(intrinsicResults);
writetable(qualityResults, fullfile(dataDir, "resource_quality_score.csv"));

optimizationResults = run_configuration_optimizer(qualityResults);
writetable(optimizationResults, fullfile(dataDir, "optimization_summary.csv"));

save(fullfile(dataDir, "qpsk_experiment_results.mat"), ...
    "p", "berResults", "bitwidthResults", "modeResults", "intrinsicResults", ...
    "srrcResults", "resourceResults", "qualityResults", "optimizationResults");

plot_ber(berResults, figDir);
plot_evm_vs_width(bitwidthResults, figDir);
plot_mode_comparison(modeResults, figDir);
plot_intrinsic_evm(intrinsicResults, figDir);
plot_srrc_comparison(srrcResults, figDir);
plot_quality_score(qualityResults, figDir);
plot_resource_estimate(resourceResults, figDir);
plot_constellation_snapshot(p, figDir);

fprintf("Simulation finished. Data: %s\n", dataDir);
fprintf("Figures: %s\n", figDir);

function p = default_params()
p.k = 2;
p.Nsym = 5000;
p.NsymBer = 50000;
p.sps = 4;
p.beta = 0.25;
p.span = 8;
p.Np = 64;
p.EbN0dB = 0:2:14;
p.bitWidths = [8 10 12 14 16];
p.modeEbN0dB = 12;
p.widthForModes = 12;
p.ddsPhaseWidth = 18;
p.ddsAddrWidth = 6;
p.ddsAmpWidth = 12;
p.cordicIter = 12;
p.cordicFracBits = 12;
p.evmTargetPct = 1.0;
end

function results = run_ber_evm_experiment(p)
rows = [];
for quantized = [false true]
    cfg = p;
    cfg.Nsym = p.NsymBer;
    cfg.mode = "BASEBAND";
    cfg.quantized = quantized;
    cfg.dataWidth = 12;
    cfg.coeffWidth = 12;
    cfg.accWidth = 20;
    for eb = p.EbN0dB
        m = simulate_qpsk_link(cfg, eb);
        rows = [rows; {string(cfg.mode), quantized, cfg.dataWidth, eb, ...
            m.ber, m.berTheory, m.evmPct, m.rxPower, m.phaseErrorDeg}]; %#ok<AGROW>
        fprintf("BER/EVM %-8s quant=%d Eb/N0=%2.0f dB: BER=%g EVM=%.3f%%\n", ...
            cfg.mode, quantized, eb, m.ber, m.evmPct);
    end
end
results = cell2table(rows, "VariableNames", ...
    ["Mode", "Quantized", "DataWidth", "EbN0dB", "BER", "BERTheory", ...
    "EVMPct", "RxSymbolPower", "PhaseErrorDeg"]);
end

function results = run_bitwidth_sweep(p)
rows = [];
for w = p.bitWidths
    cfg = p;
    cfg.mode = "BASEBAND";
    cfg.quantized = true;
    cfg.dataWidth = w;
    cfg.coeffWidth = w;
    cfg.accWidth = max(16, w + 8);
    for eb = [8 10 12 14]
        m = simulate_qpsk_link(cfg, eb);
        est = estimate_resources("BASEBAND", w);
        rows = [rows; {w, eb, m.ber, m.evmPct, est.LUT, est.FF, est.BRAM, est.DSP}]; %#ok<AGROW>
        fprintf("Width %2d Eb/N0=%2.0f dB: BER=%g EVM=%.3f%%\n", w, eb, m.ber, m.evmPct);
    end
end
results = cell2table(rows, "VariableNames", ...
    ["DataWidth", "EbN0dB", "BER", "EVMPct", "LUT_Est", "FF_Est", "BRAM_Est", "DSP_Est"]);
end

function results = run_mode_comparison(p)
modes = ["BASEBAND", "FS4_IF", "DDS_IF", "CORDIC_IF"];
rows = [];
for mode = modes
    cfg = p;
    cfg.mode = mode;
    cfg.quantized = true;
    cfg.dataWidth = p.widthForModes;
    cfg.coeffWidth = 12;
    cfg.accWidth = 20;
    m = simulate_qpsk_link(cfg, p.modeEbN0dB);
    est = estimate_resources(mode, cfg.dataWidth);
    rows = [rows; {mode, p.modeEbN0dB, m.ber, m.evmPct, ...
        est.LUT, est.FF, est.BRAM, est.DSP, est.FmaxMHz, est.LatencyCycles}]; %#ok<AGROW>
    fprintf("Mode %-9s Eb/N0=%2.0f dB: BER=%g EVM=%.3f%% LUT=%d FF=%d\n", ...
        mode, p.modeEbN0dB, m.ber, m.evmPct, est.LUT, est.FF);
end
results = cell2table(rows, "VariableNames", ...
    ["Mode", "EbN0dB", "BER", "EVMPct", "LUT_Est", "FF_Est", ...
    "BRAM_Est", "DSP_Est", "FmaxMHz_Est", "LatencyCycles_Est"]);
end

function results = run_intrinsic_evm_experiment(p)
modes = ["BASEBAND", "FS4_IF", "DDS_IF", "CORDIC_IF"];
rows = [];
for mode = modes
    for w = p.bitWidths
        cfg = p;
        cfg.mode = mode;
        cfg.quantized = true;
        cfg.dataWidth = w;
        cfg.coeffWidth = w;
        cfg.accWidth = max(16, w + 8);
        m = simulate_qpsk_link(cfg, inf);
        est = estimate_resources(mode, w);
        rows = [rows; {mode, w, m.ber, m.evmPct, est.LUT, est.FF, est.BRAM, est.DSP}]; %#ok<AGROW>
        fprintf("Intrinsic %-9s width=%2d: BER=%g EVM=%.4f%%\n", ...
            mode, w, m.ber, m.evmPct);
    end
end
results = cell2table(rows, "VariableNames", ...
    ["Mode", "DataWidth", "BER", "IntrinsicEVMPct", "LUT_Est", "FF_Est", "BRAM_Est", "DSP_Est"]);
end

function results = run_srrc_filter_comparison(p)
modes = ["BASEBAND", "FS4_IF"];
spans = [4 6 8];
rows = [];
for mode = modes
    for span = spans
        cfg = p;
        cfg.mode = mode;
        cfg.span = span;
        cfg.quantized = true;
        cfg.dataWidth = 12;
        cfg.coeffWidth = 12;
        cfg.accWidth = 20;
        taps = cfg.span * cfg.sps + 1;
        intrinsic = simulate_qpsk_link(cfg, inf);
        noisy = simulate_qpsk_link(cfg, 12);
        est = estimate_filter_resources(mode, cfg.dataWidth, taps);
        rows = [rows; {mode, taps, span, intrinsic.evmPct, noisy.ber, noisy.evmPct, ...
            est.LUT, est.FF, est.BRAM, est.DSP, est.FmaxMHz, est.LatencyCycles}]; %#ok<AGROW>
        fprintf("SRRC %-8s taps=%2d: intrinsic EVM=%.4f%%, BER@12dB=%g, LUT=%d\n", ...
            mode, taps, intrinsic.evmPct, noisy.ber, est.LUT);
    end
end
results = cell2table(rows, "VariableNames", ...
    ["Mode", "Taps", "Span", "IntrinsicEVMPct", "BER_12dB", "ChannelEVMPct_12dB", ...
    "LUT_Est", "FF_Est", "BRAM_Est", "DSP_Est", "FmaxMHz_Est", "LatencyCycles_Est"]);
end

function results = run_resource_quality_scoring(intrinsicResults)
r = intrinsicResults;
r.LatencyCycles_Est = zeros(height(r), 1);
r.FmaxMHz_Est = zeros(height(r), 1);
for ii = 1:height(r)
    est = estimate_resources(r.Mode(ii), r.DataWidth(ii));
    r.LatencyCycles_Est(ii) = est.LatencyCycles;
    r.FmaxMHz_Est(ii) = est.FmaxMHz;
end
evmNorm = normalize_metric(r.IntrinsicEVMPct, false);
lutNorm = normalize_metric(r.LUT_Est, false);
ffNorm = normalize_metric(r.FF_Est, false);
dspNorm = normalize_metric(r.DSP_Est, false);
latNorm = normalize_metric(r.LatencyCycles_Est, false);
score = 0.35 * evmNorm + 0.25 * lutNorm + 0.20 * ffNorm + 0.10 * dspNorm + 0.10 * latNorm;
r.Score = score;
r.MeetsEVM1Pct = r.IntrinsicEVMPct <= 1.0;
results = sortrows(r, "Score", "ascend");
end

function results = run_configuration_optimizer(qualityResults)
q = qualityResults(qualityResults.MeetsEVM1Pct, :);
if isempty(q)
    results = table();
    return;
end
[~, idxScore] = min(q.Score);
[~, idxLut] = min(q.LUT_Est);
[~, idxEvm] = min(q.IntrinsicEVMPct);
labels = ["Best weighted score"; "Lowest LUT under 1% EVM"; "Lowest EVM under 1% EVM"];
selected = q([idxScore; idxLut; idxEvm], :);
results = table(labels, selected.Mode, selected.DataWidth, selected.IntrinsicEVMPct, ...
    selected.LUT_Est, selected.FF_Est, selected.BRAM_Est, selected.DSP_Est, ...
    selected.LatencyCycles_Est, selected.Score, ...
    'VariableNames', {'Criterion', 'Mode', 'DataWidth', 'IntrinsicEVMPct', ...
    'LUT_Est', 'FF_Est', 'BRAM_Est', 'DSP_Est', 'LatencyCycles_Est', 'Score'});
end

function m = simulate_qpsk_link(cfg, ebN0dB)
[txBits, payloadBits, txSym, refPreamble] = make_frame(cfg);
rrc = rcosdesign(cfg.beta, cfg.span, cfg.sps, "sqrt");
if cfg.quantized
    rrc = quantize_signed(rrc, cfg.coeffWidth);
end

txUp = upsample(txSym, cfg.sps);
txBB = conv(txUp, rrc, "full");
if cfg.quantized
    txBB = quantize_signed(txBB, cfg.dataWidth);
end

[txChan, rxMixer, isRealIF] = apply_tx_mode(txBB, cfg);
rxChan = add_awgn(txChan, ebN0dB, cfg.k, cfg.sps, isRealIF);
rxBB = rxMixer(rxChan);

rxMF = conv(rxBB, rrc, "full");
if cfg.quantized
    rxMF = quantize_signed(rxMF, cfg.dataWidth);
end

[rxSym, phaseError] = synchronize_symbols(rxMF, txSym, refPreamble, cfg);
rxPayloadSym = rxSym(cfg.Np + 1:end);
txPayloadSym = txSym(cfg.Np + 1:end);
rxBitsHat = qpsk_gray_demod(rxPayloadSym);

m.ber = mean(rxBitsHat ~= payloadBits);
m.berTheory = 0.5 * erfc(sqrt(10.^(ebN0dB / 10)));
m.evmPct = 100 * sqrt(mean(abs(rxPayloadSym - txPayloadSym).^2) / mean(abs(txPayloadSym).^2));
m.rxPower = mean(abs(rxPayloadSym).^2);
m.phaseErrorDeg = phaseError * 180 / pi;
m.txBitCount = numel(txBits);
end

function [txBits, payloadBits, txSym, refPreamble] = make_frame(cfg)
preambleStream = RandStream("mt19937ar", "Seed", 20240604);
preambleBits = randi(preambleStream, [0, 1], cfg.Np * cfg.k, 1);
payloadBits = randi([0, 1], cfg.Nsym * cfg.k, 1);
txBits = [preambleBits; payloadBits];
txSym = qpsk_gray_map(txBits);
refPreamble = qpsk_gray_map(preambleBits);
end

function [txChan, rxMixer, isRealIF] = apply_tx_mode(txBB, cfg)
n = (0:numel(txBB) - 1).';
switch string(cfg.mode)
    case "BASEBAND"
        txChan = txBB;
        rxMixer = @(x) x;
        isRealIF = false;
    case "FS4_IF"
        c = cos(pi / 2 * n);
        s = sin(pi / 2 * n);
        txChan = real(txBB) .* c - imag(txBB) .* s;
        rxMixer = @(x) mix_down_if(x, n, cfg);
        isRealIF = true;
    case "DDS_IF"
        [c, s] = dds_carrier(numel(txBB), 0.25, cfg.ddsPhaseWidth, cfg.ddsAddrWidth, cfg.ddsAmpWidth);
        txChan = real(txBB) .* c - imag(txBB) .* s;
        rxMixer = @(x) mix_down_if(x, n, cfg);
        isRealIF = true;
    case "CORDIC_IF"
        [c, s] = cordic_carrier(numel(txBB), cfg.cordicIter, cfg.cordicFracBits);
        txChan = real(txBB) .* c - imag(txBB) .* s;
        rxMixer = @(x) mix_down_if(x, n, cfg);
        isRealIF = true;
    otherwise
        error("Unsupported mode: %s", cfg.mode);
end
end

function rx = add_awgn(tx, ebN0dB, k, sps, isRealIF)
if isinf(ebN0dB)
    rx = tx;
    return;
end
snrWaveDb = ebN0dB + 10 * log10(k) - 10 * log10(sps);
sigPwr = mean(abs(tx).^2);
noisePwr = sigPwr / 10^(snrWaveDb / 10);
if isRealIF
    noise = sqrt(noisePwr) * randn(size(tx));
else
    noise = sqrt(noisePwr / 2) * (randn(size(tx)) + 1j * randn(size(tx)));
end
rx = tx + noise;
end

function rxBB = mix_down_if(rxIF, n, cfg)
mixed = 2 * rxIF .* exp(-1j * pi / 2 * n);
lpOrder = 64;
cutoffNorm = min(0.9, 1.20 * (1 + cfg.beta) / cfg.sps);
lp = fir1(lpOrder, cutoffNorm);
rxBB = conv(mixed, lp, "same");
end

function [rxSym, phaseError] = synchronize_symbols(rxMF, txSym, refPreamble, cfg)
totalDelay = cfg.span * cfg.sps;
bestMetric = inf;
bestSamp = [];
for ph = 0:cfg.sps - 1
    idx0 = totalDelay + 1 + ph;
    idx = idx0:cfg.sps:(idx0 + (length(txSym) - 1) * cfg.sps);
    if idx(end) <= length(rxMF)
        cand = rxMF(idx);
        pre = cand(1:cfg.Np);
        gainPh = sum(pre .* conj(refPreamble)) / sum(abs(refPreamble).^2);
        metric = mean(abs(pre / gainPh - refPreamble).^2);
        if metric < bestMetric
            bestMetric = metric;
            bestSamp = cand(:);
        end
    end
end
if isempty(bestSamp)
    error("No valid symbol timing phase was found.");
end
phaseError = angle(sum(bestSamp(1:cfg.Np) .* conj(refPreamble)));
rxSym = bestSamp .* exp(-1j * phaseError);
gain = mean(rxSym(1:cfg.Np) ./ refPreamble);
if abs(gain) > eps
    rxSym = rxSym / gain;
end
end

function sym = qpsk_gray_map(bits)
bits = bits(:);
assert(mod(length(bits), 2) == 0, "Bit length must be even.");
b = reshape(bits, 2, []).';
idx = ones(size(b, 1), 1);
idx(b(:, 1) == 0 & b(:, 2) == 1) = 2;
idx(b(:, 1) == 1 & b(:, 2) == 1) = 3;
idx(b(:, 1) == 1 & b(:, 2) == 0) = 4;
const = [1 + 1j; -1 + 1j; -1 - 1j; 1 - 1j] / sqrt(2);
sym = const(idx);
end

function bitsHat = qpsk_gray_demod(sym)
sym = sym(:);
bitsHat = zeros(2 * numel(sym), 1);
bitsHat(1:2:end) = imag(sym) < 0;
bitsHat(2:2:end) = real(sym) < 0;
end

function y = quantize_signed(x, width)
scale = 2^(width - 1) - 1;
y = round(real(x) * scale) / scale + 1j * round(imag(x) * scale) / scale;
y = min(max(real(y), -1), 1) + 1j * min(max(imag(y), -1), 1);
end

function [c, s] = dds_carrier(nSamples, fcNorm, phaseWidth, addrWidth, ampWidth)
phaseMod = 2^phaseWidth;
phaseInc = round(fcNorm * phaseMod);
phase = mod((0:nSamples - 1).' * phaseInc, phaseMod);
theta = 2 * pi * double(phase) / phaseMod;
lutSize = 2^addrWidth;
quarter = sin((0:lutSize - 1).' / (lutSize - 1) * pi / 2);
addr = floor(mod(theta, pi / 2) / (pi / 2) * (lutSize - 1)) + 1;
quad = floor(mod(theta, 2 * pi) / (pi / 2));
sinAbs = quarter(addr);
s = sinAbs;
c = quarter(lutSize - addr + 1);
s(quad == 1) = c(quad == 1);
c(quad == 1) = -sinAbs(quad == 1);
s(quad == 2) = -sinAbs(quad == 2);
c(quad == 2) = -c(quad == 2);
s(quad == 3) = -c(quad == 3);
c(quad == 3) = sinAbs(quad == 3);
c = real(quantize_signed(c, ampWidth));
s = real(quantize_signed(s, ampWidth));
end

function [c, s] = cordic_carrier(nSamples, nIter, fracBits)
theta = mod((0:nSamples - 1).' * pi / 2 + pi, 2 * pi) - pi;
c = zeros(nSamples, 1);
s = zeros(nSamples, 1);
atanTable = atan(2.^-(0:nIter - 1));
gain = prod(1 ./ sqrt(1 + 2.^(-2 * (0:nIter - 1))));
for n = 1:nSamples
    z = theta(n);
    xSign = 1;
    if z > pi / 2
        z = z - pi;
        xSign = -1;
    elseif z < -pi / 2
        z = z + pi;
        xSign = -1;
    end
    x = gain;
    y = 0;
    for ii = 1:nIter
        d = 1;
        if z < 0, d = -1; end
        xNew = x - d * y * 2^(-(ii - 1));
        yNew = y + d * x * 2^(-(ii - 1));
        z = z - d * atanTable(ii);
        x = quant_scalar(xNew, fracBits);
        y = quant_scalar(yNew, fracBits);
        z = quant_scalar(z, fracBits);
    end
    c(n) = xSign * x;
    s(n) = xSign * y;
end
end

function y = quant_scalar(x, fracBits)
scale = 2^fracBits;
y = round(x * scale) / scale;
end

function est = estimate_resources(mode, width)
switch string(mode)
    case "BASEBAND"
        est.LUT = round(260 + 42 * width);
        est.FF = round(320 + 58 * width);
        est.BRAM = 1;
        est.DSP = double(width >= 12);
        est.FmaxMHz = round(245 - 2.5 * width);
        est.LatencyCycles = 42;
    case "FS4_IF"
        base = estimate_resources("BASEBAND", width);
        est = add_resource(base, 90, 110, 0, 0, -10, 4);
    case "DDS_IF"
        base = estimate_resources("BASEBAND", width);
        est = add_resource(base, 230, 230, 1, 0, -22, 10);
    case "CORDIC_IF"
        base = estimate_resources("BASEBAND", width);
        est = add_resource(base, 360, 430, -1, -base.DSP, -45, 18);
        est.BRAM = max(est.BRAM, 0);
        est.DSP = max(est.DSP, 0);
    otherwise
        error("Unsupported mode.");
end
end

function est = estimate_filter_resources(mode, width, taps)
baseTaps = 33;
base = estimate_resources(mode, width);
mapperLut = 180;
mapperFf = 230;
firLut = max(base.LUT - mapperLut, 0);
firFf = max(base.FF - mapperFf, 0);
scale = taps / baseTaps;
est = base;
est.LUT = round(mapperLut + firLut * scale);
est.FF = round(mapperFf + firFf * scale);
est.BRAM = double(taps >= 25);
est.DSP = double(width >= 12);
if mode ~= "BASEBAND"
    est.BRAM = max(est.BRAM, base.BRAM);
end
est.FmaxMHz = round(base.FmaxMHz + (baseTaps - taps) * 1.2);
est.LatencyCycles = max(10, round(base.LatencyCycles - (baseTaps - taps) / 2));
end

function y = normalize_metric(x, higherIsBetter)
x = double(x);
if max(x) == min(x)
    y = zeros(size(x));
elseif higherIsBetter
    y = (max(x) - x) / (max(x) - min(x));
else
    y = (x - min(x)) / (max(x) - min(x));
end
end

function out = add_resource(in, lut, ff, bram, dsp, fmax, latency)
out = in;
out.LUT = in.LUT + lut;
out.FF = in.FF + ff;
out.BRAM = in.BRAM + bram;
out.DSP = in.DSP + dsp;
out.FmaxMHz = in.FmaxMHz + fmax;
out.LatencyCycles = in.LatencyCycles + latency;
end

function results = resource_estimate_table()
modes = ["Minimal_BASEBAND"; "BASEBAND_SRRC"; "FS4_IF"; "DDS_IF"; "CORDIC_IF"];
lut = [180; 764; 854; 994; 1124];
ff = [230; 1016; 1126; 1246; 1446];
bram = [0; 1; 1; 2; 0];
dsp = [0; 1; 1; 1; 0];
fmax = [285; 215; 205; 193; 170];
lat = [4; 42; 46; 52; 60];
note = ["mapper only"; "33-tap SRRC, 12-bit fixed"; "SRRC plus multiplier-free Fs/4 mixer"; ...
    "SRRC plus quarter-wave LUT DDS"; "SRRC plus iterative CORDIC carrier"];
results = table(modes, lut, ff, bram, dsp, fmax, lat, note, ...
    'VariableNames', {'Mode', 'LUT_Est', 'FF_Est', 'BRAM_Est', 'DSP_Est', ...
    'FmaxMHz_Est', 'LatencyCycles_Est', 'Note'});
end

function plot_ber(results, figDir)
figure("Color", "w");
idxF = ~results.Quantized;
idxQ = results.Quantized;
semilogy(results.EbN0dB(idxF), max(results.BER(idxF), 1e-6), "o-", "LineWidth", 1.2); hold on;
semilogy(results.EbN0dB(idxQ), max(results.BER(idxQ), 1e-6), "s-", "LineWidth", 1.2);
semilogy(results.EbN0dB(idxF), results.BERTheory(idxF), "k--", "LineWidth", 1.2);
grid on; xlabel("E_b/N_0 (dB)"); ylabel("BER");
legend("Floating", "12-bit fixed", "Theory", "Location", "southwest");
title("QPSK BER: floating vs fixed-point baseline");
exportgraphics(gcf, fullfile(figDir, "ber_baseline.png"), "Resolution", 180);
end

function plot_evm_vs_width(results, figDir)
figure("Color", "w");
idx = results.EbN0dB == 12;
plot(results.DataWidth(idx), results.EVMPct(idx), "o-", "LineWidth", 1.2);
grid on; xlabel("Data/coefficient width (bit)"); ylabel("RMS EVM (%)");
title("EVM vs fixed-point width at E_b/N_0 = 12 dB");
exportgraphics(gcf, fullfile(figDir, "evm_vs_bitwidth.png"), "Resolution", 180);
end

function plot_mode_comparison(results, figDir)
figure("Color", "w");
tiledlayout(1, 2, "Padding", "compact");
nexttile;
bar(categorical(results.Mode), results.EVMPct);
grid on; ylabel("RMS EVM (%)"); title("Mode EVM");
nexttile;
bar(categorical(results.Mode), [results.LUT_Est results.FF_Est]);
grid on; ylabel("Estimated count"); title("Estimated resources");
legend("LUT", "FF", "Location", "northwest");
exportgraphics(gcf, fullfile(figDir, "mode_comparison.png"), "Resolution", 180);
end

function plot_intrinsic_evm(results, figDir)
figure("Color", "w");
modes = unique(results.Mode, "stable");
hold on;
for ii = 1:numel(modes)
    idx = results.Mode == modes(ii);
    plot(results.DataWidth(idx), results.IntrinsicEVMPct(idx), "o-", "LineWidth", 1.2);
end
grid on; xlabel("Data/coefficient width (bit)"); ylabel("Noiseless RMS EVM (%)");
title("Intrinsic modulator EVM vs fixed-point width");
legend(modes, "Location", "northeast");
exportgraphics(gcf, fullfile(figDir, "intrinsic_evm.png"), "Resolution", 180);
end

function plot_srrc_comparison(results, figDir)
figure("Color", "w");
tiledlayout(1, 2, "Padding", "compact");
modes = unique(results.Mode, "stable");
nexttile; hold on;
for ii = 1:numel(modes)
    idx = results.Mode == modes(ii);
    plot(results.Taps(idx), results.IntrinsicEVMPct(idx), "o-", "LineWidth", 1.2);
end
grid on; xlabel("SRRC taps"); ylabel("Noiseless RMS EVM (%)");
title("SRRC compression accuracy");
legend(modes, "Location", "northeast");
nexttile; hold on;
for ii = 1:numel(modes)
    idx = results.Mode == modes(ii);
    plot(results.Taps(idx), results.LUT_Est(idx), "s-", "LineWidth", 1.2);
end
grid on; xlabel("SRRC taps"); ylabel("Estimated LUT");
title("SRRC compression resource");
legend(modes, "Location", "northwest");
exportgraphics(gcf, fullfile(figDir, "srrc_filter_comparison.png"), "Resolution", 180);
end

function plot_quality_score(results, figDir)
topN = min(10, height(results));
top = results(1:topN, :);
labels = strings(topN, 1);
for ii = 1:topN
    labels(ii) = top.Mode(ii) + "-" + string(top.DataWidth(ii)) + "b";
end
figure("Color", "w");
bar(categorical(labels), top.Score);
grid on; ylabel("Weighted score, lower is better");
title("Top resource-quality configurations");
exportgraphics(gcf, fullfile(figDir, "resource_quality_score.png"), "Resolution", 180);
end

function plot_resource_estimate(results, figDir)
figure("Color", "w");
bar(categorical(results.Mode), [results.LUT_Est results.FF_Est]);
grid on; ylabel("Estimated count");
title("Low-resource QPSK FPGA resource estimate");
legend("LUT", "FF", "Location", "northwest");
exportgraphics(gcf, fullfile(figDir, "resource_estimate.png"), "Resolution", 180);
end

function plot_constellation_snapshot(p, figDir)
cfg = p;
cfg.mode = "FS4_IF";
cfg.quantized = true;
cfg.dataWidth = 12;
cfg.coeffWidth = 12;
cfg.accWidth = 20;
[~, ~, txSym, refPreamble] = make_frame(cfg);
rrc = quantize_signed(rcosdesign(cfg.beta, cfg.span, cfg.sps, "sqrt"), cfg.coeffWidth);
txBB = quantize_signed(conv(upsample(txSym, cfg.sps), rrc, "full"), cfg.dataWidth);
[txChan, rxMixer, isRealIF] = apply_tx_mode(txBB, cfg);
rxMF = conv(rxMixer(add_awgn(txChan, 12, cfg.k, cfg.sps, isRealIF)), rrc, "full");
[rxSym, ~] = synchronize_symbols(rxMF, txSym, refPreamble, cfg);
rxPayloadSym = rxSym(cfg.Np + 1:end);
figure("Color", "w");
plot(real(rxPayloadSym(1:1000)), imag(rxPayloadSym(1:1000)), ".", "MarkerSize", 8); hold on;
ideal = [1 + 1j; -1 + 1j; -1 - 1j; 1 - 1j] / sqrt(2);
plot(real(ideal), imag(ideal), "rx", "LineWidth", 1.5, "MarkerSize", 10);
axis equal; grid on; xlim([-1.5 1.5]); ylim([-1.5 1.5]);
xlabel("In-phase"); ylabel("Quadrature");
title("FS/4 IF fixed-point QPSK constellation at E_b/N_0 = 12 dB");
exportgraphics(gcf, fullfile(figDir, "constellation_fs4_12db.png"), "Resolution", 180);
end
