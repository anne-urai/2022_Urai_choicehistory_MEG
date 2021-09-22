function tfr_induced_evoked

% supplementary figure 1 - induced + evoked vs evoked only spectra
clear all; close all; clc;
subjectdata  = subjectspecifics('GA');

addpath(genpath('~/code/MEG'));
addpath(genpath('~/code/Tools'));
addpath('~/Documents/fieldtrip');
ft_defaults;  % ft_defaults should work in deployed app?

set(groot, 'defaultaxesfontsize', 7, 'defaultaxestitlefontsizemultiplier', 1, ...
    'defaultaxestitlefontweight', 'bold', ...
    'defaultfigurerenderermode', 'manual', 'defaultfigurerenderer', 'painters');

% ============================= %
% PLOT EVOKED VS INDUCED BASELINE-CORRECTED SPECTRA
% ============================= %

for sess = 1:2,
    
    % TAKE THE SENSORS THAT ARE SIGNIFICANT AT THE GROUP LEVEL! EXTRACT THOSE
    load(sprintf('%s/GAclean-S%d_evoked_stim_stimstrong_allindividuals.mat', subjectdata.tfrdir, sess));
    [chans, ~] = sensorplot_defineConditions(grandavg.label, 1, 'GAclean', sess);
    freq       = ft_selectdata(struct('channel', {chans(1).names}, 'avgoverchan', 'yes', ...
        'latency', [0.25 0.75], 'avgovertime', 'yes'), grandavg);
    strong = freq;
    
    load(sprintf('%s/GAclean-S%d_evoked_stim_stimweak_allindividuals.mat', subjectdata.tfrdir, sess));
    [chans, ~] = sensorplot_defineConditions(grandavg.label, 1, 'GAclean', sess);
    freq       = ft_selectdata(struct('channel', {chans(1).names}, 'avgoverchan', 'yes', ...
        'latency', [0.25 0.75], 'avgovertime', 'yes'), grandavg);
    weak = freq;
    
    % collapse
    powspctrm{sess} = squeeze(strong.powspctrm) - squeeze(weak.powspctrm);
    
end

% cat + mean over sessions
powspctrm_evoked = nanmean(cat(3, powspctrm{:}), 3);
powspctrm_evoked(find(subjectdata.all == 31), :) = [];

% ============================= %
% TOTAL POWER
% ============================= %

for sess = 1:2,
    % TAKE THE SENSORS THAT ARE SIGNIFICANT AT THE GROUP LEVEL! EXTRACT THOSE
    load(sprintf('%s/GAclean-S%d_freqbl_stim_stimstrong_allindividuals.mat', subjectdata.tfrdir, sess));
    [chans, ~] = sensorplot_defineConditions(grandavg.label, 1, 'GAclean', sess);
    freq       = ft_selectdata(struct('channel', {chans(1).names}, 'avgoverchan', 'yes', ...
        'latency', [0.25 0.75], 'avgovertime', 'yes'), grandavg);
    strong = freq;
    
    load(sprintf('%s/GAclean-S%d_freqbl_stim_stimweak_allindividuals.mat', subjectdata.tfrdir, sess));
    [chans, ~] = sensorplot_defineConditions(grandavg.label, 1, 'GAclean', sess);
    freq       = ft_selectdata(struct('channel', {chans(1).names}, 'avgoverchan', 'yes', ...
        'latency', [0.25 0.75], 'avgovertime', 'yes'), grandavg);
    weak = freq;
    
    % collapse
    powspctrm_induced{sess} = squeeze(strong.powspctrm) - squeeze(weak.powspctrm);
end
xlm = [5 120];

% cat + mean over sessions
powspctrm_induced = nanmean(cat(3, powspctrm_induced{:}), 3);
powspctrm_induced(find(subjectdata.all == 31), :) = [];

% ============================= %
% get stats - match to the correct timewin!
% ============================= %

load(sprintf('%s/%s_%s_%s_%s_freqstats_forTFR.mat', subjectdata.statsdir, ...
    'GAclean', 'stimstrong', 'stimweak', chans(1).group));

% which frequencies are significant in the 250-750ms range after stimulus onset?
usefreqs = squeeze(stat.mask(:, :, 44:53));
signific_freqs = mean(usefreqs, 2) > 0.5;

% ============================= %
% PLOT
% ============================= %

close all;
ytick = [0:20:120];
%colors = cbrewer('seq', 'Greens', 5);
colors = inferno(10);
set(gcf,'defaultAxesColorOrder', [colors(6, :); colors(6, :)]);

subplot(221); hold on;

boundedline(grandavg.freq, nanmean(powspctrm_evoked), nanstd(powspctrm_evoked) ./ sqrt(60), 'alpha', 'cmap', [ 0 0 0]);
axis tight; xlim([xlm]);
ylabel('Evoked power (\Delta%)');
set(gca, 'ytick', [-2, 0, 2], 'ylim', [-2 2], 'xtick', ytick, 'xminortick', 'on');

yyaxis right;
boundedline(grandavg.freq, nanmean(powspctrm_induced), nanstd(powspctrm_induced) ./ sqrt(60), 'alpha', 'cmap', colors(6, :));
% indicate when the contrast is significant
mn_pow = nanmean(powspctrm_induced);
mn_pow(~signific_freqs) = nan;
plot(grandavg.freq, mn_pow, '.', 'color', colors(6, :));

ylabel('Total power (\Delta%)');
freqidx = find(grandavg.freq >= 65 & grandavg.freq <= 95);
axis tight; xlim([xlm]); 
set(gca, 'ytick', [-5, 0, 5], 'ylim', [-5 5], 'xtick', ytick);
xlabel('Frequency (Hz)');
%offsetAxes;

% indicate the two different types of freqanalysis
plot([35.5 35.5], 0.9* get(gca, 'ylim'),  'w', 'linewidth', 3); % hanning up to 35, multitaper from 36 hz

% indicate alpha, beta and gamma regions
freqs = dics_freqbands;

plot([freqs(1).freq-freqs(1).tapsmofrq, ...
    freqs(1).freq+freqs(1).tapsmofrq], ...
    [2 2], '-', 'color', [0.3 0.3 0.3]);
text(freqs(1).freq, 3, '\alpha', 'fontsize', 12, ...
    'color', [0.3 0.3 0.3], 'horizontalalignment', 'center', ...
    'verticalalignment', 'cap');

% % beta
% plot([freqs(2).freq-freqs(2).tapsmofrq, ...
%     freqs(2).freq+freqs(2).tapsmofrq], ...
%     [-3 -3], '-', 'color', [0.3 0.3 0.3]);
% text(freqs(2).freq, -2, '\beta', 'fontsize', 12, ...
%     'color', [0.3 0.3 0.3], 'horizontalalignment', 'center', 'verticalalignment', 'cap');

% gamma
plot([freqs(3).freq-freqs(3).tapsmofrq, ...
    freqs(3).freq+freqs(3).tapsmofrq], ...
    [3 3], '-', 'color', [0.3 0.3 0.3]);
text(freqs(3).freq, 4, '\gamma', 'fontsize', 10, ...
    'color', [0.3 0.3 0.3], 'horizontalalignment', 'center', 'verticalalignment', 'cap');

% % broadband
% plot([freqs(4).freq-freqs(4).tapsmofrq, ...
%     freqs(4).freq+freqs(4).tapsmofrq], ...
%     [-2 -2], '-', 'color', [0.3 0.3 0.3]);
% text(freqs(4).freq, -1, 'broadband', 'fontsize', 10, ...
%     'color', [0.3 0.3 0.3], 'horizontalalignment', 'center', 'verticalalignment', 'cap');
% % 
% subplot(3,3,7);
% plot(mean(usefreqs, 2), stat.freq);
% axisNotSoTight;
% xlabel('Fraction of time significant');
% grid on;
% ylabel('Hz');
% 
% subplot(3,3,[8 9]);
% pcolor(stat.time, grandavg.freq,  double(squeeze(stat.mask)));
% plot_timename(stat.timeaxis, 0.1);
title('Strong vs. weak motion trials', 'fontweight', 'normal', 'fontangle', 'italic');

 tightfig;
print(gcf, '-dpdf', sprintf('%s/Figures/evokedinduced.pdf', subjectdata.path));


end
