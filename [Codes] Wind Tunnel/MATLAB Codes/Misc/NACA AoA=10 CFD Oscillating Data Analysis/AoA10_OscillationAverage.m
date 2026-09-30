%% Mean-flow extraction from oscillating steady RANS run (NACA 4418)
clear; clc; close all;

fname = 'cd-cl-cp-log.out';   % <-- your report file
skip  = 100;                   % start-up iterations to discard
nUse  = 4;                     % cycles to average over (uses fewer if not available)

%% Load (data starts on row 4)
D  = readmatrix(fname,'FileType','text','NumHeaderLines',3);
D  = D(all(~isnan(D),2),:);
it = D(:,1);
Y  = D(:,2:11);
names = ["Cd";"Cl";"Cp_u x/c=0.05";"Cp_u x/c=0.20";"Cp_u x/c=0.45";"Cp_u x/c=0.75"; ...
         "Cp_l x/c=0.12";"Cp_l x/c=0.27";"Cp_l x/c=0.52";"Cp_l x/c=0.68"];

%% Cycle boundaries from the taller Cd peak of each two-peak cycle
cd   = Y(:,1);
isPk = islocalmax(cd,'MinProminence',0.002,'MinSeparation',30) & it > skip;
pk   = find(isPk);
tall = pk(cd(pk) > mean(cd(pk)));
nCyc = numel(tall) - 1;
if nCyc < 2
    error('Only %d full cycle(s) after the transient. Run more iterations.', max(nCyc,0));
end
n = min(nUse, nCyc);
w = tall(end-n) : tall(end)-1;          % whole cycles, same phase at both ends
fprintf('Period ~ %.0f iterations | averaging %d cycles: iter %d-%d\n', ...
        mean(diff(tall)), n, it(w(1)), it(w(end)));

%% Statistics
mu  = mean(Y(w,:));
sd  = std(Y(w,:));
hpp = (max(Y(w,:)) - min(Y(w,:)))/2;

T = table(names, mu', sd', hpp', ...
    'VariableNames', {'Quantity','Mean','StdDev','HalfP2P'});
disp(T)

%% Has the mean settled? (last half of the cycles vs all cycles used)
nh = max(1, floor(n/2));
wh = tall(end-nh) : tall(end)-1;
shiftPct = abs(mean(Y(wh,1:2)) - mu(1:2)) ./ abs(mu(1:2)) * 100;
fprintf('Mean shift (last %d vs %d cycles): Cd %.2f%%, Cl %.2f%%\n', nh, n, shiftPct);
if any(shiftPct > 0.5)
    disp('-> Mean not settled: run more iterations.');
else
    disp('-> Mean settled: use these values.');
end

%% Plot
figure; plot(it, cd, 'b'); hold on; grid on;
plot(it(tall), cd(tall), 'rv');
xline(it(w(1)),'k--'); xline(it(w(end)),'k--');
yline(mu(1),'r-','mean');
xlabel('Iteration'); ylabel('C_d'); title('C_d history and averaging window');