%% NACA 4418 surface Cp: CFD (tap-plane .crash exports) vs wind tunnel  —  REPORT FIGURES
% Figure 1: CFD (dashed) vs WT (solid, error bars) at every AoA, 2x2 tiles
% Figure 2: upper-surface Cp vs AoA  (WT solid, CFD at taps dashed)
% Figure 3: lower-surface Cp vs AoA  (WT solid, CFD at taps dashed)
% Sized for A4, 2.5 cm margins (text width 16 cm): include with width=\textwidth.
% Saves transparent PNG (600 dpi) + transparent vector PDF.
% WT error bars: dCp = sqrt((dp/q)^2 + (Cp*2dU/U)^2)
% Requires MATLAB R2020b+.
clear; clc; close all;

%% ---------------- Settings ----------------
here   = fileparts(mfilename('fullpath'));   if isempty(here), here = pwd; end
wtFile = fullfile(here, '..', 'Wind_Tunnel_Experimental_Coefficients.xlsx');   % parent folder
if ~isfile(wtFile), error('Workbook not found: %s', wtFile); end
aoaList   = [-5 0 5 10];                                  % CFD files to load (max 4 for the 2x2 figure)
crashFmt  = fullfile(here, 'NACA %+03d AoA Cp.crash');    % 'NACA +05 AoA Cp.crash', 'NACA -05 AoA Cp.crash'
cfdLabel  = 'CFD';
faultyTap = 'Cp_l_x68';                                   % lower tap 4, omitted
showTitles = false;                                       % captions go in LaTeX
figDir  = fullfile(here, 'figures');   dpi = 600;   savePDF = true;
nPlot   = 300;                                            % CFD points kept per surface for plotting

% Uncertainty (pressure tests: speed not measured, tunnel ~16-18.5 m/s)
U = 17.5;   dU = 1.25;   rho = 1.225;   dp = 4.9;         % m/s, m/s, kg/m^3, Pa
q = 0.5*rho*U^2;
dCpFun = @(cp) sqrt((dp/q)^2 + (cp*2*dU/U).^2);

% Report style (figures made at print size -> fonts appear at FS pt)
FS = 10;   LW = 1.5;   MS = 6;   AXLW = 0.8;
cU = [0.80 0.15 0.15];   cL = [0.10 0.35 0.75];

%% ---------------- Wind-tunnel data ----------------
W = readtable(wtFile, 'Sheet', 'NACA_Cp', 'UseExcel', false);
if ismember(faultyTap, W.Properties.VariableNames), W = removevars(W, faultyTap); end
vn   = W.Properties.VariableNames;
iU   = startsWith(vn, 'Cp_u');   iL = startsWith(vn, 'Cp_l');
tapU = tapPos(vn(iU));           tapL = tapPos(vn(iL));

%% ---------------- CFD data ----------------
nA  = numel(aoaList);
cfd = struct('aoa', num2cell(aoaList));
for k = 1:nA
    fname = sprintf(crashFmt, aoaList(k));
    fprintf('Reading %s ... ', fname);   tic;
    [cfd(k).xu, cfd(k).cpu, cfd(k).xl, cfd(k).cpl] = readCrash(fname);
    cfd(k).tapU = interp1(cfd(k).xu, cfd(k).cpu, tapU);      % full data at taps
    cfd(k).tapL = interp1(cfd(k).xl, cfd(k).cpl, tapL);
    [cfd(k).pxu, cfd(k).pcu] = resampleCurve(cfd(k).xu, cfd(k).cpu, nPlot);
    [cfd(k).pxl, cfd(k).pcl] = resampleCurve(cfd(k).xl, cfd(k).cpl, nPlot);
    fprintf('%d points, %.1f s\n', numel(cfd(k).xu) + numel(cfd(k).xl), toc);
end

%% ---------------- Printed table ----------------
fprintf('\nNACA 4418 - Cp at tap locations   (diff = WT - CFD;  +/- = WT uncertainty)\n');
for k = 1:nA
    r = find(W.AoA_deg == aoaList(k), 1);
    fprintf('\nAoA = %+d deg\n', aoaList(k));
    fprintf('  %-7s %6s %8s %7s %8s %8s\n', 'Surface', 'x/c', 'WT', '+/-', 'CFD', 'diff');
    printTaps('Upper', tapU, getWT(W, r, iU), cfd(k).tapU, dCpFun);
    printTaps('Lower', tapL, getWT(W, r, iL), cfd(k).tapL, dCpFun);
end
fprintf('\n');

%% ---------------- Figure 1: 2x2, CFD vs WT at every AoA ----------------
fig = newFig(16, 15);
t   = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
axs = gobjects(1, nA);   allY = [];
for k = 1:nA
    a  = aoaList(k);   r = find(W.AoA_deg == a, 1);
    wu = getWT(W, r, iU);   wl = getWT(W, r, iL);
    ax = nexttile(t);   axs(k) = ax;   hold(ax, 'on');
    zeroLine(ax);
    h = gobjects(1, 5);
    h(1) = plot(ax, cfd(k).pxu, cfd(k).pcu, '--', 'Color', cU, 'LineWidth', LW);
    h(2) = plot(ax, cfd(k).pxl, cfd(k).pcl, '--', 'Color', cL, 'LineWidth', LW);
    h(3) = plot(ax, [tapU tapL], [cfd(k).tapU cfd(k).tapL], 'kx', 'MarkerSize', MS, 'LineWidth', 1.1);
    h(4) = wtSeries(ax, tapU, wu, dCpFun(wu), '-o', cU, LW, MS);
    h(5) = wtSeries(ax, tapL, wl, dCpFun(wl), '-s', cL, LW, MS);
    styleAx(ax, FS, AXLW);
    set(ax, 'YDir', 'reverse');   xlim(ax, [0 1]);
    title(ax, sprintf('\\alpha = %d^\\circ', a), 'FontSize', FS, 'FontWeight', 'normal');
    allY = [allY; cfd(k).pcu(:); cfd(k).pcl(:); wu(:) + dCpFun(wu(:)); wu(:) - dCpFun(wu(:)); ...
            wl(:) + dCpFun(wl(:)); wl(:) - dCpFun(wl(:))]; %#ok<AGROW>
end
yr = [min(allY) max(allY)];   set(axs, 'YLim', yr + [-1 1]*0.05*diff(yr));
xlabel(t, 'x/c', 'FontSize', FS);   ylabel(t, 'C_p', 'FontSize', FS);
if showTitles, title(t, sprintf('NACA 4418 surface pressure: %s vs wind tunnel', cfdLabel), 'FontSize', FS); end
lgd = legend(axs(end), h, {[cfdLabel ', upper surface'], [cfdLabel ', lower surface'], [cfdLabel ' at taps'], ...
             'Wind tunnel, upper taps', 'Wind tunnel, lower taps'}, 'NumColumns', 3, 'FontSize', FS - 1, 'Color', 'none');
lgd.Layout.Tile = 'south';
saveFig(fig, figDir, 'NACA_Cp_CFD_vs_WT_all_AoA', dpi, savePDF);

%% ---------------- Figures 2-3: Cp vs AoA per surface ----------------
wtA  = sort(W.AoA_deg).';
cols = lines(numel(wtA));
mk   = {'o', 's', '^', 'd', 'v', '>', '<', 'p'};
surfs = {'upper', iU, tapU, 'tapU'; 'lower', iL, tapL, 'tapL'};
for s = 1:2
    xT  = surfs{s,3};
    fig = newFig(16, 11);   ax = gca;   hold(ax, 'on');
    zeroLine(ax);
    h = gobjects(1, numel(wtA));   lg = cell(1, numel(wtA));
    for k = 1:numel(wtA)
        m  = mk{mod(k-1, numel(mk)) + 1};
        kc = find(aoaList == wtA(k), 1);
        if ~isempty(kc)
            plot(ax, xT, cfd(kc).(surfs{s,4}), ['--' m], 'Color', cols(k,:), 'MarkerFaceColor', 'w', ...
                 'LineWidth', LW - 0.2, 'MarkerSize', MS, 'HandleVisibility', 'off');
        end
        r  = find(W.AoA_deg == wtA(k), 1);
        cp = getWT(W, r, surfs{s,2});
        h(k) = wtSeries(ax, xT, cp, dCpFun(cp), ['-' m], cols(k,:), LW, MS);
        lg{k} = sprintf('\\alpha = %d^\\circ', wtA(k));
    end
    hW = plot(ax, NaN, NaN, '-o',  'Color', [0.3 0.3 0.3], 'MarkerFaceColor', [0.3 0.3 0.3], 'LineWidth', LW);
    hC = plot(ax, NaN, NaN, '--o', 'Color', [0.3 0.3 0.3], 'MarkerFaceColor', 'w', 'LineWidth', LW - 0.2);
    styleAx(ax, FS, AXLW);
    set(ax, 'YDir', 'reverse');
    xlim(ax, [floor(round((min(xT) - 0.05)*20, 6)), ceil(round((max(xT) + 0.05)*20, 6))] / 20);
    xlabel(ax, 'x/c');   ylabel(ax, 'C_p');
    if showTitles, title(ax, sprintf('NACA 4418 %s surface: C_p vs angle of attack', surfs{s,1}), 'FontWeight', 'normal'); end
    legend(ax, [h hW hC], [lg, {'Wind tunnel', [cfdLabel ' (at taps)']}], ...
           'Location', 'southoutside', 'NumColumns', 3, 'FontSize', FS - 1, 'Color', 'none');
    saveFig(fig, figDir, ['NACA_Cp_' surfs{s,1} '_vs_AoA'], dpi, savePDF);
end

%% ======================= Local functions =======================
function fig = newFig(wcm, hcm)
fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 wcm hcm]);
end

function styleAx(ax, FS, AXLW)
set(ax, 'FontSize', FS, 'LineWidth', AXLW, 'Box', 'on', 'Layer', 'top', 'TickDir', 'in');
grid(ax, 'on');   ax.GridAlpha = 0.15;
ax.Color = 'none';                                    % transparent plot area
end

function zeroLine(ax)
yline(ax, 0, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 0.8, 'HandleVisibility', 'off');
end

function h = wtSeries(ax, x, y, e, spec, col, LW, MS)
h = errorbar(ax, x, y, e, spec, 'Color', col, 'MarkerFaceColor', col, ...
             'LineWidth', LW, 'MarkerSize', MS, 'CapSize', 4);
end

function [xu, cpu, xl, cpl] = readCrash(fname)
if ~isfile(fname), error('File not found: %s', fname); end
T  = readtable(fname, 'FileType', 'text', 'Delimiter', ',', 'VariableNamingRule', 'preserve');
x  = T{:,2};  y = T{:,3};  cp = T{:,5};          % columns: node, x, y, z, Cp
[~, iTE] = max(x);                               % TE = most downstream point
d2 = (x - x(iTE)).^2 + (y - y(iTE)).^2;
[~, iLE] = max(d2);                              % LE = farthest point from TE
c  = sqrt(d2(iLE));
ch = [x(iTE) - x(iLE), y(iTE) - y(iLE)] / c;     % unit chord
nh = [-ch(2), ch(1)];                            % unit normal, upper side positive
xc   = ((x - x(iLE))*ch(1) + (y - y(iLE))*ch(2)) / c;
side =  (x - x(iLE))*nh(1) + (y - y(iLE))*nh(2);
up   = side >= 0;   lo = ~up;
[xu, cpu] = cleanSort(xc(up), cp(up));
[xl, cpl] = cleanSort(xc(lo), cp(lo));
end

function [xs, cs] = cleanSort(x, c)
[xs, ~, ic] = unique(x);
cs = accumarray(ic, c, [], @mean);
end

function [xp, cp] = resampleCurve(x, c, n)
t  = (1 - cos(linspace(0, pi, n))) / 2;          % dense at LE and TE
xp = min(x) + (max(x) - min(x)) * t;
cp = interp1(x, c, xp);
end

function x = tapPos(names)
x = str2double(extractAfter(names, '_x')) / 100;   % 'Cp_u_x05' -> 0.05
end

function v = getWT(W, r, idx)
if isempty(r), v = NaN(1, nnz(idx)); else, v = W{r, idx}; end
end

function printTaps(name, x, wt, cf, dCpFun)
for j = 1:numel(x)
    fprintf('  %-7s %6.2f %8.3f %7.3f %8.3f %+8.3f\n', name, x(j), wt(j), dCpFun(wt(j)), cf(j), wt(j) - cf(j));
end
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