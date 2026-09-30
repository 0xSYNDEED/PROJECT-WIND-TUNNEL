%% Cp distribution at the tap plane: split upper/lower, normalise to x/c
clear; clc; close all;

fname = 'NACA +10 AoA Cp.crash';     % ASCII export of the tap-plane line on the airfoil walls
T = readtable(fname, 'FileType','text', 'Delimiter',',', 'VariableNamingRule','preserve');
x  = T{:,2}; y = T{:,3}; cp = T{:,5};   % columns: node, x, y, z, Cp (check the header)

% Chord line: TE = most downstream point, LE = point farthest from TE
[~,iTE] = max(x);
d2 = (x-x(iTE)).^2 + (y-y(iTE)).^2;
[~,iLE] = max(d2);
c  = sqrt(d2(iLE));
ch = [x(iTE)-x(iLE), y(iTE)-y(iLE)]/c;   % unit chord vector
nh = [-ch(2), ch(1)];                    % unit normal, upper side positive

xc   = ((x-x(iLE))*ch(1) + (y-y(iLE))*ch(2))/c;   % x/c along the rotated chord
side = (x-x(iLE))*nh(1) + (y-y(iLE))*nh(2);
up = side >= 0;  lo = ~up;

[xu,cpu] = cleanSort(xc(up), cp(up));
[xl,cpl] = cleanSort(xc(lo), cp(lo));

% CFD Cp at the tap locations
tapU = [0.05 0.20 0.45 0.75];  tapL = [0.12 0.27 0.52 0.68];
cpTapU = interp1(xu,cpu,tapU);  cpTapL = interp1(xl,cpl,tapL);
Cp_upper = cpTapU
Cp_lower = cpTapL

% Plot
figure; hold on; box on; grid on;
plot(xu,cpu,'r-','LineWidth',1.5);
plot(xl,cpl,'b-','LineWidth',1.5);
plot(tapU,cpTapU,'rs','MarkerFaceColor','w');
plot(tapL,cpTapL,'bs','MarkerFaceColor','w');
set(gca,'YDir','reverse');                 % aerodynamics convention: suction up
xlabel('x/c'); ylabel('C_p');
legend('Upper (CFD)','Lower (CFD)','Upper taps','Lower taps','Location','southeast');

function [xs,cs] = cleanSort(x,c)
[xs,~,ic] = unique(x);
cs = accumarray(ic, c, [], @mean);     % merge duplicate x values
end