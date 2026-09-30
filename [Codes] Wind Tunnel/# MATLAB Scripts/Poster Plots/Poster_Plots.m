%% POSTER FIGURES — wind tunnel vs CFD (bold, thick lines, high resolution)
% Figure 1: NACA 4418 Cp, CFD curve vs WT taps at +5 and +10 deg (1x2)
% Figure 2: NACA 4418 L/D vs AoA - WT vs CFD with stand vs CFD without stand
% Figure 3: Ahmed body upper-surface Cp - CFD curve + tap means vs WT
% All inputs are expected in the same folder as this script.
% Requires MATLAB R2020b+ (tiledlayout legend tile, exportgraphics).
clear; clc; close all;

%% ---------------- Settings ----------------
here      = fileparts(mfilename('fullpath'));   if isempty(here), here = pwd; end
wtFile    = fullfile(here, 'Wind_Tunnel_Experimental_Coefficients.xlsx');
cfdFile   = fullfile(here, 'CFD_Results.xlsx');
crashFmt  = fullfile(here, 'NACA %+03d AoA Cp.crash');
ahmedSnap = fullfile(here, 'Ahmed Cp.crash');
ahmedStat = fullfile(here, 'ahmed_cfd_stats.csv');
for f = {wtFile, cfdFile, ahmedSnap, ahmedStat}
    if ~isfile(f{1}), error('File not found: %s', f{1}); end
end

posterAoA  = [5 10];              % angles shown in figure 1
faultyTap  = 'Cp_l_x68';          % lower tap 4, omitted
cfdLabel   = 'CFD';
showTitles = true;
figDir     = fullfile(here, 'poster_figures');
dpi        = 600;

% Uncertainty inputs (same as the report scripts)
rho = 1.225;   dp = 4.9;          % kg/m^3, Pa (10-bit ADC at 1 kPa/V)
U_N = 17.5;    dU_Cp = 1.25;      % NACA Cp: speed not measured (16-18.5 m/s)
dU_F = 0.5;    dF_g  = 3;         % NACA forces (retest): m/s, g
A_N  = 0.0125;                    % NACA reference area, m^2
U_A  = 16;     dU_A  = 0.5;       % Ahmed Cp

% Poster style
FS  = 15;   LW = 2.6;   MS = 9;   AXLW = 1.6;
cU = [0.80 0.12 0.12];   cL = [0.10 0.32 0.75];                   % NACA upper / lower
cW = [0.20 0.20 0.20];   cS = [0.85 0.33 0.10];   cN = [0.00 0.45 0.74];   % WT / CFD stand / CFD no stand

%% =================== FIGURE 1: NACA Cp at +5 and +10 deg ===================
W = readtable(wtFile, 'Sheet', 'NACA_Cp', 'UseExcel', false);
if ismember(faultyTap, W.Properties.VariableNames), W = removevars(W, faultyTap); end
vn = W.Properties.VariableNames;
iU = startsWith(vn, 'Cp_u');   iL = startsWith(vn, 'Cp_l');
tapU = tapPos(vn(iU));         tapL = tapPos(vn(iL));
qN   = 0.5*rho*U_N^2;
dCp  = @(cp, q, dU, U) sqrt((dp/q)^2 + (cp*2*dU/U).^2);

fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 30 14]);
t   = tiledlayout(fig, 1, numel(posterAoA), 'TileSpacing', 'compact', 'Padding', 'compact');
axs = gobjects(1, numel(posterAoA));   allY = [];
for k = 1:numel(posterAoA)
    a = posterAoA(k);
    fprintf('Reading %s\n', sprintf(crashFmt, a));
    [xu, cpu, xl, cpl] = readCrash(sprintf(crashFmt, a));
    cfdTU = interp1(xu, cpu, tapU);   cfdTL = interp1(xl, cpl, tapL);
    [pxu, pcu] = resampleCurve(xu, cpu, 300);   [pxl, pcl] = resampleCurve(xl, cpl, 300);
    r  = find(W.AoA_deg == a, 1);
    if isempty(r), error('No wind-tunnel Cp row for AoA = %d.', a); end
    wu = W{r, iU};   wl = W{r, iL};
    eu = dCp(wu, qN, dU_Cp, U_N);   el = dCp(wl, qN, dU_Cp, U_N);

    ax = nexttile(t);   axs(k) = ax;   hold(ax, 'on');
    yline(ax, 0, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.2, 'HandleVisibility', 'off');
    h = gobjects(1, 5);
    h(1) = plot(ax, pxu, pcu, '--', 'Color', cU, 'LineWidth', LW);
    h(2) = plot(ax, pxl, pcl, '--', 'Color', cL, 'LineWidth', LW);
    h(3) = plot(ax, [tapU tapL], [cfdTU cfdTL], 'kx', 'MarkerSize', MS + 1, 'LineWidth', 2);
    h(4) = errorbar(ax, tapU, wu, eu, '-o', 'Color', cU, 'MarkerFaceColor', cU, ...
                    'LineWidth', LW, 'MarkerSize', MS, 'CapSize', 8);
    h(5) = errorbar(ax, tapL, wl, el, '-s', 'Color', cL, 'MarkerFaceColor', cL, ...
                    'LineWidth', LW, 'MarkerSize', MS, 'CapSize', 8);
    posterAx(ax, FS, AXLW);
    set(ax, 'YDir', 'reverse');   xlim(ax, [0 1]);
    title(ax, sprintf('\\alpha = %+d^\\circ', a), 'FontSize', FS + 1, 'FontWeight', 'bold');
    allY = [allY; pcu(:); pcl(:); wu(:) + eu(:); wu(:) - eu(:); wl(:) + el(:); wl(:) - el(:)]; %#ok<AGROW>
end
yr = [min(allY) max(allY)];   set(axs, 'YLim', yr + [-1 1]*0.06*diff(yr));
xlabel(t, 'x/c', 'FontSize', FS + 1, 'FontWeight', 'bold');
ylabel(t, 'C_p', 'FontSize', FS + 1, 'FontWeight', 'bold');
if showTitles
    title(t, 'NACA 4418 surface pressure: CFD vs wind tunnel', 'FontSize', FS + 2, 'FontWeight', 'bold');
end
lgd = legend(axs(end), h, {[cfdLabel ', upper surface'], [cfdLabel ', lower surface'], [cfdLabel ' at taps'], ...
             'Wind tunnel, upper taps', 'Wind tunnel, lower taps'}, 'NumColumns', 3, ...
             'FontSize', FS - 1, 'FontWeight', 'bold', 'Color', 'none');
lgd.Layout.Tile = 'south';
saveFig(fig, figDir, 'Poster_NACA_Cp_5_10', dpi);

%% =================== FIGURE 2: NACA L/D ===================
Wf = readtable(wtFile,  'Sheet', 'NACA_Forces', 'UseExcel', false);
Cf = readtable(cfdFile, 'Sheet', 'NACA_Forces', 'UseExcel', false);
M  = sortrows(innerjoin(Wf, Cf, 'Keys', 'AoA_deg'), 'AoA_deg');
a  = M.AoA_deg;
LD = [M.Cl./M.Cd, M.Cl_stand./M.Cd_stand, M.Cl_nostand./M.Cd_nostand];
qF = 0.5*rho*U_N^2;   dF = dF_g/1000*9.81;
L  = M.Cl*qF*A_N;     D  = M.Cd*qF*A_N;
dLD = abs(LD(:,1)) .* sqrt((dF./L).^2 + (dF./D).^2);      % q cancels in L/D

fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 20 14]);
ax  = gca;   hold(ax, 'on');
yline(ax, 0, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.2, 'HandleVisibility', 'off');
h = gobjects(1, 3);
h(1) = errorbar(ax, a, LD(:,1), dLD, '-o', 'Color', cW, 'MarkerFaceColor', cW, ...
                'LineWidth', LW, 'MarkerSize', MS, 'CapSize', 8);
h(2) = plot(ax, a, LD(:,2), '--s', 'Color', cS, 'MarkerFaceColor', 'w', 'LineWidth', LW, 'MarkerSize', MS);
h(3) = plot(ax, a, LD(:,3), '--^', 'Color', cN, 'MarkerFaceColor', 'w', 'LineWidth', LW, 'MarkerSize', MS);
posterAx(ax, FS, AXLW);
set(ax, 'XTick', a);   xlim(ax, [min(a) max(a)] + [-1.5 1.5]);
xlabel(ax, 'Angle of attack, \alpha (^\circ)', 'FontWeight', 'bold');
ylabel(ax, 'Lift-to-drag ratio, C_l / C_d', 'FontWeight', 'bold');
if showTitles
    title(ax, 'NACA 4418 lift-to-drag ratio', 'FontSize', FS + 1, 'FontWeight', 'bold');
end
legend(ax, h, {'Wind tunnel', 'CFD (with stand)', 'CFD (without stand)'}, ...
       'Location', 'northwest', 'FontSize', FS - 1, 'FontWeight', 'bold', 'Color', 'none');
saveFig(fig, figDir, 'Poster_NACA_LD', dpi);

%% =================== FIGURE 3: Ahmed body Cp ===================
T = readtable(ahmedSnap, 'FileType', 'text', 'Delimiter', ',', 'VariableNamingRule', 'preserve');
[x, s] = sort(T{:,2});   cpS = T{s,5};
xS = (x - min(x)) / 0.120;                                  % body length 120 mm
S  = readtable(ahmedStat, 'VariableNamingRule', 'preserve');
isTap = startsWith(string(S.Quantity), "Cp");
xt = S.x_L(isTap);   mt = S.Mean(isTap);   st = S.StdDev(isTap);
Wa = sortrows(readtable(wtFile, 'Sheet', 'Ahmed_Cp', 'UseExcel', false), 'x_L');
ea = dCp(Wa.Cp, 0.5*rho*U_A^2, dU_A, U_A);

fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 22 14]);
ax  = gca;   hold(ax, 'on');
yline(ax, 0, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.2, 'HandleVisibility', 'off');
h = gobjects(1, 3);
h(1) = plot(ax, xS, cpS, '--', 'Color', cS, 'LineWidth', LW);
h(3) = errorbar(ax, Wa.x_L, Wa.Cp, ea, '-o', 'Color', cW, 'MarkerFaceColor', cW, ...
                'LineWidth', LW, 'MarkerSize', MS, 'CapSize', 8);
h(2) = errorbar(ax, xt, mt, st, 's', 'Color', cS, 'MarkerFaceColor', 'w', ...
                'LineWidth', 2, 'MarkerSize', MS + 1, 'CapSize', 8);
posterAx(ax, FS, AXLW);
set(ax, 'YDir', 'reverse');   xlim(ax, [0 1]);
xlabel(ax, 'x/L', 'FontWeight', 'bold');   ylabel(ax, 'C_p', 'FontWeight', 'bold');
if showTitles
    title(ax, 'Ahmed body upper surface pressure', 'FontSize', FS + 1, 'FontWeight', 'bold');
end
legend(ax, h, {'CFD (with stand)', 'CFD tap mean \pm 1\sigma', 'Wind tunnel'}, ...
       'Location', 'best', 'FontSize', FS - 1, 'FontWeight', 'bold', 'Color', 'none');
saveFig(fig, figDir, 'Poster_Ahmed_Cp', dpi);

%% ======================= Local functions =======================
function posterAx(ax, FS, AXLW)
set(ax, 'FontSize', FS, 'FontWeight', 'bold', 'LineWidth', AXLW, 'Box', 'on', ...
        'Layer', 'top', 'TickLength', [0.015 0.015]);
grid(ax, 'on');   ax.GridAlpha = 0.2;
ax.Color = 'none';                                   % transparent plot area
end

function [xu, cpu, xl, cpl] = readCrash(fname)
if ~isfile(fname), error('File not found: %s', fname); end
T  = readtable(fname, 'FileType', 'text', 'Delimiter', ',', 'VariableNamingRule', 'preserve');
x  = T{:,2};  y = T{:,3};  cp = T{:,5};
[~, iTE] = max(x);
d2 = (x - x(iTE)).^2 + (y - y(iTE)).^2;
[~, iLE] = max(d2);
c  = sqrt(d2(iLE));
ch = [x(iTE) - x(iLE), y(iTE) - y(iLE)] / c;
nh = [-ch(2), ch(1)];
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
t  = (1 - cos(linspace(0, pi, n))) / 2;       % cosine spacing: dense at LE and TE
xp = min(x) + (max(x) - min(x)) * t;
cp = interp1(x, c, xp);
end

function x = tapPos(names)
x = str2double(extractAfter(names, '_x')) / 100;
end

function saveFig(fig, figDir, name, dpi)
% PDF: vector, transparent background.
% PNG: transparent via two exports (white & black background) -> exact alpha,
%      so anti-aliased edges have no white halo on a coloured poster.
if ~isfolder(figDir), mkdir(figDir); end
fprintf('Saving %s\n', name);   drawnow;
exportgraphics(fig, fullfile(figDir, [name '.pdf']), 'ContentType', 'vector', 'BackgroundColor', 'none');

tmpW = [tempname '.png'];   tmpB = [tempname '.png'];
exportgraphics(fig, tmpW, 'Resolution', dpi, 'BackgroundColor', [1 1 1]);
exportgraphics(fig, tmpB, 'Resolution', dpi, 'BackgroundColor', [0 0 0]);
Iw = double(imread(tmpW)) / 255;   Ib = double(imread(tmpB)) / 255;
delete(tmpW);   delete(tmpB);
if ~isequal(size(Iw), size(Ib))
    warning('%s: export sizes differ, saving PNG with white background instead.', name);
    imwrite(Iw, fullfile(figDir, [name '.png']));
    return
end
alpha = 1 - mean(Iw - Ib, 3);                     % Iw - Ib = 1 - alpha
alpha = min(max(alpha, 0), 1);
C     = min(max(Ib ./ max(alpha, 1e-6), 0), 1);   % un-premultiply colour
imwrite(C, fullfile(figDir, [name '.png']), 'Alpha', alpha);
end