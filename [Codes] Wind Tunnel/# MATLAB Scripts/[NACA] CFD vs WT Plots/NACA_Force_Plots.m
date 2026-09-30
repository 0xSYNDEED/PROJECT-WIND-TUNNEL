%% NACA 4418 force coefficients: wind tunnel vs CFD (with / without stand)  —  REPORT FIGURES
% Figure 1: Cl at each AoA (grouped bars)     Figure 2: Cd at each AoA (grouped bars)
% Figure 3: L/D vs AoA (WT solid with error bars, CFD dashed)
% Prints a comparison table (3 significant figures) with WT uncertainty and errors.
% Sized for A4, 2.5 cm margins (text width 16 cm): include with width=\textwidth.
% Saves transparent PNG (600 dpi) + transparent vector PDF.
% WT uncertainty:  dCl = sqrt((dL/(q*A))^2 + (Cl*2dU/U)^2)  (same for Cd),
%                  d(L/D)/(L/D) = sqrt((dL/L)^2 + (dD/D)^2)  (q cancels)
% Requires MATLAB R2020b+.
clear; clc; close all;

%% ---------------- Settings ----------------
here    = fileparts(mfilename('fullpath'));   if isempty(here), here = pwd; end
wtFile  = fullfile(here, '..', 'Wind_Tunnel_Experimental_Coefficients.xlsx');   % parent folder
cfdFile = fullfile(here, 'CFD_Results.xlsx');
if ~isfile(wtFile),  error('Workbook not found: %s', wtFile);  end
if ~isfile(cfdFile), error('Workbook not found: %s', cfdFile); end
showTitles = false;                                     % captions go in LaTeX
figDir = fullfile(here, 'figures');   dpi = 600;   savePDF = true;

% Uncertainty (tunnel speed range ~16-18.5 m/s -> half-range; conservative for the pitot-measured retest)
U = 17.5;   dU = 0.5;   rho = 1.225;   A = 0.0125;   gAcc = 9.81;
dL_g = 3;   dD_g = 3;                                   % g, half the +/-2.5 g fluctuation band, rounded up

% Report style
FS = 10;   LW = 1.5;   MS = 6;   AXLW = 0.8;
src  = {'Wind tunnel', 'CFD (with stand)', 'CFD (without stand)'};
cols = [0.25 0.25 0.25;  0.85 0.33 0.10;  0.00 0.45 0.74];

%% ---------------- Data ----------------
W = readtable(wtFile,  'Sheet', 'NACA_Forces', 'UseExcel', false);   % AoA_deg, Cl, Cd
C = readtable(cfdFile, 'Sheet', 'NACA_Forces', 'UseExcel', false);   % AoA_deg, Cl_stand, Cd_stand, Cl_nostand, Cd_nostand
M = sortrows(innerjoin(W, C, 'Keys', 'AoA_deg'), 'AoA_deg');
a = M.AoA_deg;
Cl = [M.Cl, M.Cl_stand, M.Cl_nostand];
Cd = [M.Cd, M.Cd_stand, M.Cd_nostand];
LD = Cl ./ Cd;

%% ---------------- WT uncertainty ----------------
q    = 0.5*rho*U^2;   dq_q = 2*dU/U;
dL   = dL_g/1000*gAcc;   dD = dD_g/1000*gAcc;
L    = M.Cl*q*A;         D  = M.Cd*q*A;
dCl  = sqrt((dL/(q*A))^2 + (M.Cl*dq_q).^2);
dCd  = sqrt((dD/(q*A))^2 + (M.Cd*dq_q).^2);
dLD  = abs(LD(:,1)) .* sqrt((dL./L).^2 + (dD./D).^2);

%% ---------------- Figures ----------------
fig = barCompare(a, Cl, dCl, cols, src, 'Lift coefficient, C_l', FS, AXLW);
if showTitles, title('NACA 4418 lift coefficient', 'FontWeight', 'normal'); end
saveFig(fig, figDir, 'NACA_Cl_WT_vs_CFD', dpi, savePDF);

fig = barCompare(a, Cd, dCd, cols, src, 'Drag coefficient, C_d', FS, AXLW);
if showTitles, title('NACA 4418 drag coefficient', 'FontWeight', 'normal'); end
saveFig(fig, figDir, 'NACA_Cd_WT_vs_CFD', dpi, savePDF);

fig = lineCompare(a, LD, dLD, cols, src, 'Lift-to-drag ratio, C_l / C_d', FS, LW, MS, AXLW);
if showTitles, title('NACA 4418 lift-to-drag ratio', 'FontWeight', 'normal'); end
saveFig(fig, figDir, 'NACA_LD_WT_vs_CFD', dpi, savePDF);

%% ---------------- Comparison table ----------------
qty = {'Cl', 'Cd', 'L/D'};   V = {Cl, Cd, LD};   E = {dCl, dCd, dLD};
fmt = '%-4s %4s | %8s %7s | %10s %8s | %12s %8s\n';
hr  = repmat('-', 1, 74);
fprintf('NACA 4418 - wind tunnel vs CFD\n');
fprintf('Error = (WT - CFD) / |CFD| x 100 %%;  +/- = WT uncertainty   (3 significant figures)\n');
fprintf('%s\n', hr);
fprintf(fmt, 'Qty', 'AoA', 'WT', '+/-', 'CFD stand', 'Err %', 'CFD nostand', 'Err %');
fprintf('%s\n', hr);
for iq = 1:numel(qty)
    for i = 1:numel(a)
        wt = V{iq}(i,1);  st = V{iq}(i,2);  ns = V{iq}(i,3);
        lbl = '';  if i == 1, lbl = qty{iq}; end
        fprintf(fmt, lbl, sprintf('%d', a(i)), sig3(wt), sig3(E{iq}(i)), ...
                sig3(st), pctErr(wt, st), sig3(ns), pctErr(wt, ns));
    end
    fprintf('%s\n', hr);
end

%% ======================= Local functions =======================
function fig = barCompare(a, Y, eWT, cols, src, yl, FS, AXLW)
fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 16 9.5]);
ax  = gca;   hold(ax, 'on');
b = bar(ax, a, Y, 'grouped', 'EdgeColor', 'none', 'BarWidth', 0.85);
for j = 1:numel(b), b(j).FaceColor = cols(j,:); end
errorbar(ax, b(1).XEndPoints, Y(:,1).', eWT.', 'k', 'LineStyle', 'none', ...
         'LineWidth', 1, 'CapSize', 4, 'HandleVisibility', 'off');
yline(ax, 0, 'k-', 'LineWidth', 0.6, 'HandleVisibility', 'off');
styleAx(ax, a, 3, FS, AXLW);                           % bars need room for the group width
ax.XGrid = 'off';
ylabel(ax, yl);
legend(b, src, 'Location', 'northwest', 'FontSize', FS - 1, 'Color', 'none');
end

function fig = lineCompare(a, Y, eWT, cols, src, yl, FS, LW, MS, AXLW)
fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 16 10]);
ax  = gca;   hold(ax, 'on');
yline(ax, 0, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 0.8, 'HandleVisibility', 'off');
h = gobjects(1, 3);
h(1) = errorbar(ax, a, Y(:,1), eWT, '-o', 'Color', cols(1,:), 'MarkerFaceColor', cols(1,:), ...
                'LineWidth', LW, 'MarkerSize', MS, 'CapSize', 4);
h(2) = plot(ax, a, Y(:,2), '--s', 'Color', cols(2,:), 'MarkerFaceColor', 'w', 'LineWidth', LW, 'MarkerSize', MS);
h(3) = plot(ax, a, Y(:,3), '--^', 'Color', cols(3,:), 'MarkerFaceColor', 'w', 'LineWidth', LW, 'MarkerSize', MS);
styleAx(ax, a, 1.5, FS, AXLW);
ylabel(ax, yl);
legend(h, src, 'Location', 'northwest', 'FontSize', FS - 1, 'Color', 'none');
end

function styleAx(ax, a, pad, FS, AXLW)
set(ax, 'FontSize', FS, 'LineWidth', AXLW, 'Box', 'on', 'Layer', 'top', 'XTick', a);
grid(ax, 'on');   ax.GridAlpha = 0.15;
ax.Color = 'none';                                     % transparent plot area
xlim(ax, [min(a) max(a)] + [-pad pad]);
xlabel(ax, 'Angle of attack, \alpha (^\circ)');
end

function s = sig3(x)
if isnan(x), s = '-'; else, s = sprintf('%g', round(x, 3, 'significant')); end
end

function s = pctErr(wt, ref)
e = (wt - ref) / abs(ref) * 100;
if ~isfinite(e), s = '-'; else, s = sprintf('%+g', round(e, 3, 'significant')); end
end

function saveFig(fig, figDir, name, dpi, savePDF)
% Transparent PNG via white/black double export (exact alpha, no halos) + optional vector PDF.
if ~isfolder(figDir), mkdir(figDir); end
fprintf('Saving %s\n', name);   drawnow;
if savePDF
    exportgraphics(fig, fullfile(figDir, [name '.pdf']), 'ContentType', 'vector', 'BackgroundColor', 'none');
end
tmpW = [tempname '.png'];   tmpB = [tempname '.png'];
exportgraphics(fig, tmpW, 'Resolution', dpi, 'BackgroundColor', [1 1 1]);
exportgraphics(fig, tmpB, 'Resolution', dpi, 'BackgroundColor', [0 0 0]);
Iw = double(imread(tmpW)) / 255;   Ib = double(imread(tmpB)) / 255;
delete(tmpW);   delete(tmpB);
if ~isequal(size(Iw), size(Ib))
    warning('%s: export sizes differ, PNG saved with white background.', name);
    imwrite(Iw, fullfile(figDir, [name '.png']));   return
end
alpha = min(max(1 - mean(Iw - Ib, 3), 0), 1);
C     = min(max(Ib ./ max(alpha, 1e-6), 0), 1);
imwrite(C, fullfile(figDir, [name '.png']), 'Alpha', alpha);
end