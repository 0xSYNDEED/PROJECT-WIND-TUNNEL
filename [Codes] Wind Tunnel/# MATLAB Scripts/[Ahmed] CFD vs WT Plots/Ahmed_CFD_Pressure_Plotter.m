%% Ahmed body: snapshot upper-surface Cp curve + averaged tap values (±1 SD)
clear; clc; close all;

snapFile  = 'Ahmed Cp.crash';   % ASCII export of the upper-surface iso-line: node, x, y, z, Cp
statsFile = 'ahmed_cfd_stats.csv';    % output of the averaging script
Lbody     = 0.120;                    % [m] body length (nose to base)

%% Snapshot curve
T  = readtable(snapFile,'FileType','text','Delimiter',',','VariableNamingRule','preserve');
[x,s] = sort(T{:,2});
cp    = T{s,5};
x0    = min(x);                       % nose position
fprintf('Line spans %.1f mm of %.1f mm body length\n', (max(x)-x0)*1000, Lbody*1000);
xL = (x - x0)/Lbody;

%% Averaged tap values
S     = readtable(statsFile,'VariableNamingRule','preserve');
isTap = startsWith(string(S.Quantity), "Cp");
xt = S.x_L(isTap);  mt = S.Mean(isTap);  st = S.StdDev(isTap);

%% Plot
figure; hold on; box on; grid on;
plot(xL, cp, 'r-', 'LineWidth', 1.5);
errorbar(xt, mt, st, 'ks', 'MarkerFaceColor','w', 'LineWidth',1.2, 'CapSize',8);
set(gca,'YDir','reverse');
xlabel('x/L'); ylabel('C_p');
title('Ahmed body: upper-surface C_p at tap plane');
legend('CFD snapshot (upper surface)', 'CFD tap mean \pm 1\sigma', 'Location','best');