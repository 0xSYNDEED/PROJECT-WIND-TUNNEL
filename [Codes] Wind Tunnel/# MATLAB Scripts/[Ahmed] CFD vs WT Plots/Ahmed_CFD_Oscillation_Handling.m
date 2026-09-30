%% Ahmed body: average oscillating monitors from the Fluent report file
clear; clc; close all;

fname  = 'cd-cp-ahmed_315.out';      % Fluent report file
outCSV = 'ahmed_cfd_stats.csv';    % output statistics
i1     = 100;                      % window start (after the transient)
i2     = Inf;                      % window end (Inf = last iteration)

%% Load (data starts on row 4): Iteration, cd, cps(t1)...cps(t8)
D  = readmatrix(fname,'FileType','text','NumHeaderLines',3);
D  = D(all(~isnan(D),2),:);
it = D(:,1);
Y  = D(:,2:10);

names = ["Cd";"Cp_t1";"Cp_t2";"Cp_t3";"Cp_t4";"Cp_t5";"Cp_t6";"Cp_t7";"Cp_t8"];
xL    = [NaN; 0.05; 0.13; 0.32; 0.55; 0.72; 0.82; 0.90; 0.96];   % tap x/L

%% Averaging window
w  = it >= i1 & it <= i2;
iw = find(w);
if numel(iw) < 100
    warning('Only %d iterations in the window; aim for ~200.', numel(iw));
end
fprintf('Averaging iterations %d-%d (%d samples)\n', it(iw(1)), it(iw(end)), numel(iw));

%% Statistics
Yw  = Y(w,:);
mu  = mean(Yw)';
sd  = std(Yw)';
hpp = (max(Yw) - min(Yw))'/2;
mn  = min(Yw)';
mx  = max(Yw)';

T = table(names, xL, mu, sd, hpp, mn, mx, ...
    'VariableNames', {'Quantity','x_L','Mean','StdDev','HalfP2P','Min','Max'});
disp(T)
writetable(T, outCSV);
fprintf('Saved %s\n', outCSV);

%% Has the mean settled? (first half vs second half of the window)
h  = floor(numel(iw)/2);
m1 = mean(Y(iw(1:h),:));
m2 = mean(Y(iw(h+1:end),:));
fprintf('Cd mean shift between halves: %.2f%%\n', abs(m2(1)-m1(1))/abs(m1(1))*100);
fprintf('Max Cp mean shift between halves: %.4f\n', max(abs(m2(2:end)-m1(2:end))));
if abs(m2(1)-m1(1))/abs(m1(1))*100 > 0.5
    disp('-> Cd mean not settled: run more iterations.');
else
    disp('-> Mean settled.');
end