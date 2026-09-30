%% Ahmed body: surface Cp and drag coefficient, wind tunnel vs CFD (with stand)  —  REPORT FIGURE
% Figure: CFD upper-surface Cp curve (dashed) + CFD tap means (+/- 1 SD) vs WT taps (solid, error bars)
% Prints a drag-coefficient comparison: WT vs CFD with stand / without stand.
% Sized for A4, 2.5 cm margins (text width 16 cm): include with width=\textwidth.
% Saves transparent PNG (600 dpi) + transparent vector PDF.
% WT uncertainty:  dCp = sqrt((dp/q)^2 + (Cp*2*dU_Cp/U)^2),  dCd = sqrt((dD/(q*A))^2 + (Cd*2*dU_Cd/U)^2)
%   dU_Cp = 1.25 m/s: taps read at nominal speed; the +/-1.25 m/s speed fluctuation is not tracked
%   dU_Cd = 0.5 m/s:  drag point taken with the Pitot-measured speed
% Requires MATLAB R2020b+.
clear; clc; close all;

%% ---------------- Settings ----------------
here      = fileparts(mfilename('fullpath'));   if isempty(here), here = pwd; end
wtFile    = fullfile(here, '..', 'Wind_Tunnel_Experimental_Coefficients.xlsx');   % parent folder
snapFile  = fullfile(here, 'Ahmed Cp.crash');         % upper-surface iso-line: node, x, y, z, Cp
statsFile = fullfile(here, 'ahmed_cfd_stats.csv');    % output of the averaging script
for f = {wtFile, snapFile, statsFile}
    if ~isfile(f{1}), error('File not found: %s', f{1}); end
end
Lbody      = 0.120;                                   % m, body length (nose to base)
showTitles = false;                                   % captions go in LaTeX
figDir = fullfile(here, 'figures');   dpi = 600;   savePDF = true;

% CFD drag coefficients (stored here)
Cd_stand    = 0.6159;   % with stand, U = 16 m/s, mean over logged iterations
Cd_stand_sd = 0.0035;   % 1 SD of the oscillation
Cd_nostand  = 0.4431;   % model only, U = 17.5 m/s (from D = 0.123 N)

% Uncertainty
U = 16;   dU_Cp = 1.25;   dU_Cd = 0.5;   rho = 1.225;   A = 0.00148;   dp = 4.9;   dD_g = 3;

% Report style
FS = 10;   LW = 1.5;   MS = 6;   AXLW = 0.8;
cW = [0.25 0.25 0.25];   cC = [0.85 0.33 0.10];

%% ---------------- Data ----------------
T = readtable(snapFile, 'FileType', 'text', 'Delimiter', ',', 'VariableNamingRule', 'preserve');
[x, s] = sort(T{:,2});   cpS = T{s,5};   x0 = min(x);
fprintf('CFD line spans %.1f mm of %.1f mm body length\n\n', (max(x) - x0)*1000, Lbody*1000);
xS = (x - x0) / Lbody;

S     = readtable(statsFile, 'VariableNamingRule', 'preserve');
isTap = startsWith(string(S.Quantity), "Cp");
xt = S.x_L(isTap);   mt = S.Mean(isTap);   st = S.StdDev(isTap);

Wcp  = sortrows(readtable(wtFile, 'Sheet', 'Ahmed_Cp', 'UseExcel', false), 'x_L');
Wf   = readtable(wtFile, 'Sheet', 'Ahmed_Forces', 'UseExcel', false);
q    = 0.5*rho*U^2;   dqq_Cp = 2*dU_Cp/U;   dqq_Cd = 2*dU_Cd/U;
dCp  = sqrt((dp/q)^2 + (Wcp.Cp*dqq_Cp).^2);
cdWT = Wf.Cd(1);
dCd  = sqrt((dD_g/1000*9.81/(q*A))^2 + (cdWT*dqq_Cd)^2);

%% ---------------- Figure ----------------
fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 16 9.5]);
ax  = gca;   hold(ax, 'on');
yline(ax, 0, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 0.8, 'HandleVisibility', 'off');
h = gobjects(1, 3);
h(1) = plot(ax, xS, cpS, '--', 'Color', cC, 'LineWidth', LW);
h(3) = errorbar(ax, Wcp.x_L, Wcp.Cp, dCp, '-o', 'Color', cW, 'MarkerFaceColor', cW, ...
                'LineWidth', LW, 'MarkerSize', MS, 'CapSize', 4);
h(2) = errorbar(ax, xt, mt, st, 's', 'Color', cC, 'MarkerFaceColor', 'w', ...
                'LineWidth', 1.1, 'MarkerSize', MS + 1, 'CapSize', 4);
set(ax, 'YDir', 'reverse', 'FontSize', FS, 'LineWidth', AXLW, 'Box', 'on', 'Layer', 'top');
grid(ax, 'on');   ax.GridAlpha = 0.15;   ax.Color = 'none';
xlim(ax, [0 1]);
xlabel(ax, 'x/L');   ylabel(ax, 'C_p');
if showTitles, title(ax, 'Ahmed body upper surface: C_p', 'FontWeight', 'normal'); end
legend(ax, h, {'CFD (with stand), upper surface', 'CFD (with stand), tap mean \pm 1\sigma', 'Wind tunnel'}, ...
       'Location', 'best', 'FontSize', FS - 1, 'Color', 'none');
saveFig(fig, figDir, 'Ahmed_Cp_WT_vs_CFD', dpi, savePDF);

%% ---------------- Drag comparison ----------------
name = {'Wind tunnel'; 'CFD (with stand)'; 'CFD (without stand)'};
cdv  = [cdWT; Cd_stand; Cd_nostand];
unc  = [dCd; Cd_stand_sd; NaN];
fmt  = '%-22s %8s %8s %12s\n';
hr   = repmat('-', 1, 53);
fprintf('Ahmed body - drag coefficient\n');
fprintf('WT error = (WT - CFD) / CFD x 100 %%;  +/- = WT uncertainty or CFD 1 SD\n');
fprintf('%s\n', hr);
fprintf(fmt, 'Source', 'Cd', '+/-', 'WT error %');
fprintf('%s\n', hr);
for i = 1:numel(name)
    if i == 1, e = '-'; else, e = sprintf('%+g', round((cdWT - cdv(i)) / cdv(i) * 100, 3, 'significant')); end
    fprintf(fmt, name{i}, sig3(cdv(i)), sig3(unc(i)), e);
end
fprintf('%s\n', hr);

%% ======================= Local functions =======================
function s = sig3(x)
if isnan(x), s = '-'; else, s = sprintf('%g', round(x, 3, 'significant')); end
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