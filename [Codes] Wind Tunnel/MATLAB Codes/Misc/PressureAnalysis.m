% NACA 4418 surface-pressure analysis
% CSV format:
% 1,Upper,346.87
% ...
%
% The first 4 rows are Upper taps in order.
% The next 4 rows are Lower taps in order.
%
% Test condition:
% U_inf = 18.1 m/s
% AoA = 0 +/- 5 deg
%
% NOTE:
% The supplied pressure values are treated as SIGNED surface pressure
% differences dp = p_s - p_inf. Therefore no polarity flip is applied.

clear; clc; close all;

%% User settings
csvFile = 'surface_pressure.csv';
excelFile = 'NACA4418_surface_pressure_results.xlsx';

U_inf = 17.5;       % m/s
rho   = 1.225;       % kg/m^3
a     = 340.3;       % m/s, speed of sound at ~15 C
mu    = 1.81e-5;     % Pa.s, dynamic viscosity of air

AoA_text = '0 +/- 5 deg';

% NACA 4418, chord = 100 mm
c = 0.100;           % m

xcp_upper = [0.05 0.20 0.45 0.75];
xcp_lower = [0.12 0.27 0.52 0.68];

%% Derived freestream quantities
q_inf = 0.5*rho*U_inf^2;
Mach  = U_inf/a;
Re    = rho*U_inf*c/mu;

%% Read CSV
T = readtable(csvFile, ...
    'ReadVariableNames', false, ...
    'Delimiter', ',');

% Expected columns: tap number, surface, pressure
T.Properties.VariableNames = {'Tap','Surface','Pressure'};

% Force numeric pressure column
T.Pressure = double(T.Pressure);

% First 4 = upper, next 4 = lower
%dp_upper = T.Pressure(1:4).';
%dp_lower = T.Pressure(5:8).';
p2 = [-14, -88, -68, -10];
pl2 = [-60, -34, -20, -30];
dp_upper = p2;
dp_lower = pl2;

%% Assign x/c and x
x_upper = xcp_upper * c;
x_lower = xcp_lower * c;

%% Surface velocities from Bernoulli
% Cp = (p_s-p_inf)/q_inf
% For incompressible Bernoulli:
% p_s-p_inf = 0.5*rho*(U_inf^2-U^2)
% Therefore U/U_inf = sqrt(1-Cp)

Cp_upper = dp_upper ./ q_inf;
Cp_lower = dp_lower ./ q_inf;

% Guard against negative values inside sqrt
u_ratio_upper = sqrt(max(0,1-Cp_upper));
u_ratio_lower = sqrt(max(0,1-Cp_lower));

u_upper = U_inf .* u_ratio_upper;
u_lower = U_inf .* u_ratio_lower;

% Mach number at each pressure tap
Mach_upper = u_upper ./ a;
Mach_lower = u_lower ./ a;

%% Print results
fprintf('\n============================================\n');
fprintf('NACA 4418 SURFACE PRESSURE ANALYSIS\n');
fprintf('============================================\n');
fprintf('U_inf = %.2f m/s\n', U_inf);
fprintf('AoA   = %s\n', AoA_text);
fprintf('Chord = %.0f mm\n', c*1000);
fprintf('q_inf = %.2f Pa\n', q_inf);
fprintf('Re    = %.3e\n', Re);
fprintf('Mach_inf = %.4f\n', Mach);
fprintf('============================================\n\n');

fprintf('dp_upper = [%s];\n', sprintf('%.2f ', dp_upper));
fprintf('dp_lower = [%s];\n\n', sprintf('%.2f ', dp_lower));

fprintf('Cp_upper = [%s];\n', sprintf('%.4f ', Cp_upper));
fprintf('Cp_lower = [%s];\n\n', sprintf('%.4f ', Cp_lower));

fprintf('u_upper = [%s];  %% m/s\n', sprintf('%.4f ', u_upper));
fprintf('u_lower = [%s];  %% m/s\n\n', sprintf('%.4f ', u_lower));

fprintf('u_uinf_upper = [%s];\n', sprintf('%.4f ', u_ratio_upper));
fprintf('u_uinf_lower = [%s];\n\n', sprintf('%.4f ', u_ratio_lower));

fprintf('Mach_upper = [%s];\n', sprintf('%.5f ', Mach_upper));
fprintf('Mach_lower = [%s];\n\n', sprintf('%.5f ', Mach_lower));

%% Figure 1: Pressure difference vs x/c
figure('Name','Surface Pressure','Color','w');
plot(xcp_upper, dp_upper, '-o', 'LineWidth', 1.5, 'MarkerSize', 7);
hold on;
plot(xcp_lower, dp_lower, '-s', 'LineWidth', 1.5, 'MarkerSize', 7);
grid on;

xlabel('x/c');
ylabel('\Delta p = p_s - p_\infty (Pa)');
title('NACA 4418 Surface Pressure Distribution');
legend('Upper surface','Lower surface','Location','best');

%% Figure 2: Cp vs x/c
figure('Name','Cp Distribution','Color','w');
plot(xcp_upper, Cp_upper, '-o', 'LineWidth', 1.5, 'MarkerSize', 7);
hold on;
plot(xcp_lower, Cp_lower, '-s', 'LineWidth', 1.5, 'MarkerSize', 7);
yline(0,'--','LineWidth',1);

grid on;
xlabel('x/c');
ylabel('C_p');
title(sprintf('NACA 4418 Pressure Coefficient Distribution, AoA = %s', AoA_text));
legend('Upper surface','Lower surface','C_p = 0','Location','best');

%% Figure 3: Local velocity vs x/c
figure('Name','Surface Velocity','Color','w');
plot(xcp_upper, u_upper, '-o', 'LineWidth', 1.5, 'MarkerSize', 7);
hold on;
plot(xcp_lower, u_lower, '-s', 'LineWidth', 1.5, 'MarkerSize', 7);
yline(U_inf,'--','LineWidth',1);

grid on;
xlabel('x/c');
ylabel('Local velocity, U (m/s)');
title('NACA 4418 Local Surface Velocity Distribution');
legend('Upper surface','Lower surface','Freestream U_\infty','Location','best');

%% Figure 4: Non-dimensional velocity vs x/c
figure('Name','Non-dimensional Velocity','Color','w');
plot(xcp_upper, u_ratio_upper, '-o', 'LineWidth', 1.5, 'MarkerSize', 7);
hold on;
plot(xcp_lower, u_ratio_lower, '-s', 'LineWidth', 1.5, 'MarkerSize', 7);
yline(1,'--','LineWidth',1);

grid on;
xlabel('x/c');
ylabel('U/U_\infty');
title('NACA 4418 Non-dimensional Surface Velocity');
legend('Upper surface','Lower surface','Freestream U/U_\infty = 1','Location','best');

%% Create Excel output
Tap = [1;2;3;4;1;2;3;4];
Surface = ["Upper";"Upper";"Upper";"Upper"; ...
           "Lower";"Lower";"Lower";"Lower"];

x_over_c = [xcp_upper.'; xcp_lower.'];
x_mm = x_over_c * c * 1000;

Pressure_Pa = [dp_upper.'; dp_lower.'];
Cp = [Cp_upper.'; Cp_lower.'];
U_mps = [u_upper.'; u_lower.'];
U_over_Uinf = [u_ratio_upper.'; u_ratio_lower.'];
Mach_local = [Mach_upper.'; Mach_lower.'];

Results = table(Tap,Surface,x_over_c,x_mm,Pressure_Pa,Cp,U_mps,U_over_Uinf,Mach_local);

% Write main data sheet
writetable(Results, excelFile, 'Sheet', 'Surface Data');

% Metadata sheet
Parameter = [
    "Model"
    "Chord"
    "Freestream velocity U_inf"
    "Angle of attack"
    "Air density"
    "Dynamic pressure q_inf"
    "Reynolds number Re"
    "Freestream Mach number"
    "Speed of sound"
    "Dynamic viscosity"
    ];

Value = [
    "NACA 4418"
    sprintf('%.0f mm',c*1000)
    sprintf('%.2f m/s',U_inf)
    AoA_text
    sprintf('%.4f kg/m^3',rho)
    sprintf('%.2f Pa',q_inf)
    sprintf('%.4e',Re)
    sprintf('%.5f',Mach)
    sprintf('%.2f m/s',a)
    sprintf('%.4e Pa.s',mu)
    ];

Metadata = table(Parameter,Value);
writetable(Metadata, excelFile, 'Sheet', 'Test Information');

fprintf('Excel file generated: %s\n', excelFile);
