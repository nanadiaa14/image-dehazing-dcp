clc; clear; close all;

img = imread('bantaeng2.jpeg');
img = img(:,:,1:3);
img_uint8 = img;
img_double = im2double(img);

% ===================== PARAMETER DEFAULT =====================
patch_size = 15;
omega      = 0.95;
t_min      = 0.1;
r          = 60;
eps        = 1e-3;

% ===================== PIPELINE UTAMA =====================
fprintf('===== PIPELINE DCP - PARAMETER DEFAULT =====\n');

dark_ch = dark_channel(img_double, patch_size);
fprintf('Dark channel selesai\n');

A = estimate_atmospheric_light(img_double, dark_ch);
fprintf('Atmospheric Light - R:%.4f G:%.4f B:%.4f\n', A(1), A(2), A(3));

t_raw = estimate_transmission(img_double, A, patch_size, omega);
fprintf('Transmission map raw selesai\n');

gray_img = rgb2gray(img_double);
t_refined = guided_filter(gray_img, t_raw, r, eps);
t_refined = max(t_refined, t_min);
fprintf('Guided filter selesai\n');

J_dcp = reconstruct(img_double, A, t_refined, t_min);
fprintf('Rekonstruksi selesai\n');

e_original = compute_entropy(img_double);
e_dcp      = compute_entropy(J_dcp);
n_original = compute_niqe(img_double);
n_dcp      = compute_niqe(J_dcp);

fprintf('\n===== EVALUASI DEFAULT =====\n');
fprintf('Entropy - Original: %.4f | DCP Default: %.4f\n', e_original, e_dcp);
fprintf('NIQE    - Original: %.4f | DCP Default: %.4f\n', n_original, n_dcp);

% ===================== VISUALISASI PIPELINE =====================
figure('Name', 'Pipeline DCP');
subplot(2,3,1); imshow(img_double);        title('1. Original');
subplot(2,3,2); imshow(dark_ch);           title('2. Dark Channel');
subplot(2,3,3); imshow(t_raw);             title('3. Transmission Raw');
subplot(2,3,4); imshow(t_refined);         title('4. Transmission Refined');
subplot(2,3,5); imshow(J_dcp);             title('5. Hasil DCP Default');
subplot(2,3,6);
imhist(rgb2gray(im2uint8(img_double))); hold on;
imhist(rgb2gray(im2uint8(J_dcp)));
title('6. Histogram Perbandingan');
legend('Original','DCP Default');

% ===================== SENSITIVITY ANALYSIS =====================

% --- 1. Variasi patch_size ---
fprintf('\n===== SENSITIVITY: patch_size =====\n');
patch_list     = [5, 10, 15, 25];
e_patch_list   = zeros(1, length(patch_list));
n_patch_list   = zeros(1, length(patch_list));
figure('Name', 'Sensitivity: patch_size');
for i = 1:length(patch_list)
    ps      = patch_list(i);
    dc_temp = dark_channel(img_double, ps);
    A_temp  = estimate_atmospheric_light(img_double, dc_temp);
    t_temp  = estimate_transmission(img_double, A_temp, ps, omega);
    t_temp  = guided_filter(gray_img, t_temp, r, eps);
    J_temp  = reconstruct(img_double, A_temp, t_temp, t_min);
    e_patch_list(i) = compute_entropy(J_temp);
    n_patch_list(i) = compute_niqe(J_temp);
    fprintf('patch_size=%2d | Entropy=%.4f | NIQE=%.4f\n', ps, e_patch_list(i), n_patch_list(i));
    subplot(2,4,i);   imshow(J_temp); title(sprintf('patch=%d', ps));
    subplot(2,4,i+4); imshow(dark_channel(img_double, ps)); title(sprintf('DC patch=%d', ps));
end

% --- 2. Variasi omega ---
fprintf('\n===== SENSITIVITY: omega =====\n');
omega_list   = [0.7, 0.85, 0.95, 1.0];
e_omega_list = zeros(1, length(omega_list));
n_omega_list = zeros(1, length(omega_list));
figure('Name', 'Sensitivity: omega');
for i = 1:length(omega_list)
    om     = omega_list(i);
    t_temp = estimate_transmission(img_double, A, patch_size, om);
    t_temp = guided_filter(gray_img, t_temp, r, eps);
    J_temp = reconstruct(img_double, A, t_temp, t_min);
    e_omega_list(i) = compute_entropy(J_temp);
    n_omega_list(i) = compute_niqe(J_temp);
    fprintf('omega=%.2f | Entropy=%.4f | NIQE=%.4f\n', om, e_omega_list(i), n_omega_list(i));
    subplot(1,4,i); imshow(J_temp); title(sprintf('omega=%.2f', om));
end

% --- 3. Variasi t_min ---
fprintf('\n===== SENSITIVITY: t_min =====\n');
tmin_list   = [0.05, 0.1, 0.2, 0.3];
e_tmin_list = zeros(1, length(tmin_list));
n_tmin_list = zeros(1, length(tmin_list));
figure('Name', 'Sensitivity: t_min');
for i = 1:length(tmin_list)
    tm     = tmin_list(i);
    J_temp = reconstruct(img_double, A, t_refined, tm);
    e_tmin_list(i) = compute_entropy(J_temp);
    n_tmin_list(i) = compute_niqe(J_temp);
    fprintf('t_min=%.2f | Entropy=%.4f | NIQE=%.4f\n', tm, e_tmin_list(i), n_tmin_list(i));
    subplot(1,4,i); imshow(J_temp); title(sprintf('t\\_min=%.2f', tm));
end

% --- 4. Variasi guided filter radius ---
fprintf('\n===== SENSITIVITY: guided filter radius =====\n');
r_list   = [20, 40, 60, 80];
e_r_list = zeros(1, length(r_list));
n_r_list = zeros(1, length(r_list));
figure('Name', 'Sensitivity: guided filter radius');
for i = 1:length(r_list)
    ri     = r_list(i);
    t_temp = estimate_transmission(img_double, A, patch_size, omega);
    t_temp = guided_filter(gray_img, t_temp, ri, eps);
    J_temp = reconstruct(img_double, A, t_temp, t_min);
    e_r_list(i) = compute_entropy(J_temp);
    n_r_list(i) = compute_niqe(J_temp);
    fprintf('r=%2d | Entropy=%.4f | NIQE=%.4f\n', ri, e_r_list(i), n_r_list(i));
    subplot(2,4,i);   imshow(J_temp);   title(sprintf('r=%d hasil', ri));
    subplot(2,4,i+4); imshow(guided_filter(gray_img, t_raw, ri, eps)); title(sprintf('r=%d t\\_refined', ri));
end

% ===================== PENENTUAN PARAMETER TERBAIK OTOMATIS =====================
fprintf('\n===== PENENTUAN PARAMETER TERBAIK =====\n');
fprintf('Kriteria: Entropy tertinggi per parameter (Gao et al., 2018)\n\n');

[~, idx] = max(e_patch_list);
best_patch = patch_list(idx);
fprintf('best patch_size : %d  (Entropy=%.4f)\n', best_patch, e_patch_list(idx));

[~, idx] = max(e_omega_list);
best_omega = omega_list(idx);
fprintf('best omega      : %.2f (Entropy=%.4f)\n', best_omega, e_omega_list(idx));

best_tmin = t_min;
fprintf('best t_min      : %.2f (tidak sensitif, pakai default He et al. 2009)\n', best_tmin);

[~, idx] = max(e_r_list);
best_r = r_list(idx);
fprintf('best r          : %d   (Entropy=%.4f)\n', best_r, e_r_list(idx));

% ===================== PIPELINE DCP PARAMETER TERBAIK =====================
fprintf('\n===== PIPELINE DCP - PARAMETER TERBAIK =====\n');

dark_ch_best   = dark_channel(img_double, best_patch);
A_best         = estimate_atmospheric_light(img_double, dark_ch_best);
fprintf('Atmospheric Light Best - R:%.4f G:%.4f B:%.4f\n', A_best(1), A_best(2), A_best(3));

t_raw_best     = estimate_transmission(img_double, A_best, best_patch, best_omega);
t_refined_best = guided_filter(gray_img, t_raw_best, best_r, eps);
t_refined_best = max(t_refined_best, best_tmin);
J_best         = reconstruct(img_double, A_best, t_refined_best, best_tmin);

e_best = compute_entropy(J_best);
n_best = compute_niqe(J_best);

% ===================== EVALUASI PERBANDINGAN AKHIR =====================
fprintf('\n===== EVALUASI PERBANDINGAN AKHIR =====\n');
fprintf('%-25s | Entropy | NIQE\n', 'Metode');
fprintf('%s\n', repmat('-', 1, 45));
fprintf('%-25s | %.4f  | %.4f\n', 'Original',           e_original, n_original);
fprintf('%-25s | %.4f  | %.4f\n', 'DCP Default (He09)', e_dcp,      n_dcp);
fprintf('%-25s | %.4f  | %.4f\n', 'DCP Best Parameter', e_best,     n_best);

% ===================== VISUALISASI PERBANDINGAN AKHIR =====================
figure('Name', 'Perbandingan Akhir');
subplot(1,3,1); imshow(img_double);
    title('Original');
subplot(1,3,2); imshow(J_dcp);
    title(sprintf('DCP Default\npatch=%d, \\omega=%.2f, r=%d', patch_size, omega, r));
subplot(1,3,3); imshow(J_best);
    title(sprintf('DCP Best\npatch=%d, \\omega=%.2f, r=%d', best_patch, best_omega, best_r));

% ===================== SIMPAN HASIL =====================
imwrite(img_double,          'result_original-rev.png');
imwrite(J_dcp,               'result_dcp_default-rev.png');
imwrite(J_best,              'result_dcp_best-rev.png');
imwrite(mat2gray(dark_ch),   'result_darkch-rev.png');
imwrite(mat2gray(t_raw),     'result_transmission_raw-rev.png');
imwrite(mat2gray(t_refined), 'result_transmission_refined-rev.png');
fprintf('\nSemua hasil tersimpan.\n');

% ===================== FUNGSI DCP =====================

function result = dark_channel(img, patch_size)
    min_channel = min(img, [], 3);
    kernel = ones(patch_size, patch_size);
    result = imerode(min_channel, kernel);
end

function A = estimate_atmospheric_light(img, dark_ch)
    [h, w, ~] = size(img);
    num_pixels = h * w;
    num_brightest = max(floor(num_pixels * 0.001), 1);
    dark_vec = reshape(dark_ch, [], 1);
    img_vec = reshape(img, [], 3);
    [~, idx] = sort(dark_vec, 'descend');
    brightest = img_vec(idx(1:num_brightest), :);
    A = double(max(brightest, [], 1));
end

function t = estimate_transmission(img, A, patch_size, omega)
    norm_img = img;
    norm_img(:,:,1) = img(:,:,1) / A(1);
    norm_img(:,:,2) = img(:,:,2) / A(2);
    norm_img(:,:,3) = img(:,:,3) / A(3);
    dark_norm = dark_channel(norm_img, patch_size);
    t = 1 - omega * dark_norm;
end

function output = boxfilter(img, r)
    [h, w] = size(img);
    output = cumsum(img, 1);
    temp = zeros(h, w);
    for i = 1:h
        if i + r <= h
            temp(i,:) = output(i+r,:);
        else
            temp(i,:) = output(h,:);
        end
        if i - r - 1 >= 1
            temp(i,:) = temp(i,:) - output(i-r-1,:);
        end
    end
    output = temp;
    output = cumsum(output, 2);
    temp2 = zeros(h, w);
    for j = 1:w
        if j + r <= w
            temp2(:,j) = output(:,j+r);
        else
            temp2(:,j) = output(:,w);
        end
        if j - r - 1 >= 1
            temp2(:,j) = temp2(:,j) - output(:,j-r-1);
        end
    end
    output = temp2;
end

function refined = guided_filter(I, p, r, eps)
    I = double(I);
    p = double(p);
    [h, w] = size(I);
    N = boxfilter(ones(h, w), r);
    mean_I = boxfilter(I, r) ./ N;
    mean_p = boxfilter(p, r) ./ N;
    mean_Ip = boxfilter(I .* p, r) ./ N;
    cov_Ip = mean_Ip - mean_I .* mean_p;
    mean_II = boxfilter(I .* I, r) ./ N;
    var_I = mean_II - mean_I .* mean_I;
    a = cov_Ip ./ (var_I + eps);
    b = mean_p - a .* mean_I;
    mean_a = boxfilter(a, r) ./ N;
    mean_b = boxfilter(b, r) ./ N;
    refined = mean_a .* I + mean_b;
end

function J = reconstruct(img, A, t, t_min)
    t = max(t, t_min);
    J = zeros(size(img));
    for c = 1:3
        J(:,:,c) = (img(:,:,c) - A(c)) ./ t + A(c);
    end
    J = max(0, min(1, J));
end

function e = compute_entropy(img)
    gray = rgb2gray(im2uint8(img));
    counts = histcounts(gray(:), 0:256);
    p = counts / numel(gray);
    p = p(p > 0);
    e = -sum(p .* log2(p));
end

function score = compute_niqe(img)
    gray = im2uint8(rgb2gray(img));
    score = niqe(gray);
end