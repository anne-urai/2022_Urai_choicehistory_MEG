function dics_stats_groupdiff()

close all; clc;
set(groot, 'DefaultFigureWindowStyle','normal', 'DefaultAxesFontSize', 3);
sjdat = subjectspecifics('ga');

%% =========================================== %
% GET TABLES WITH INDIVIDUAL ESTIMATES
% =========================================== %

freqs = dics_freqbands;
for v = 1:3,
    filename = sprintf('S%d_%s_%s', 0, freqs(v).name, 'glme');
    tab{v} = readtable(sprintf('%s/effectsizes_%s.csv', sjdat.statsdir, freqs(v).name));
end
tab = vertcat(tab{:});
% remove duplicates
[~, ind] = unique(tab(:, {'subj_idx', 'contrast', 'formula', 'freq', ...
    'session', 'roi', 'var', 'timewin', 'group'}), 'rows');
tab = tab(ind,:);

% FDR correction
[~, crit_p, ~, adj_p] = fdr_bh(tab.pval(~isnan(tab.pval)));
tab.adj_p = nan(size(tab.pval));
tab.adj_p(~isnan(tab.pval)) = adj_p; % use adjusted values

% ====================================================================================== %
% MAKE NICER-LOOKING BARGRAPHS
% 1. IPS2/3 gamma, test stimulus, contrast 4
% ====================================================================================== %

rois = {'wang_vfc_IPS2/3', 'wang_vfc_IPS0/1', 'pooled_motor_lateralized'};
contrasts = {{4,8,'prev_resp', 'stimulus'}, {5,9,'prev_hand', 'reference'}};
for v = [3 2 1],
    for r = 1:length(rois),
        for c = 1:length(contrasts),
        
        neural_data_alternators = tab(tab.contrast == contrasts{c}{1} & ...
            strcmp(tab.var, contrasts{c}{3}) & ...
            contains(tab.roi, rois{r}) &  ...
            contains(tab.freq, freqs(v).name) & ...
            tab.session == 0 & ...
            tab.subj_idx == 0 & ...
            strcmp(tab.group, 'alternators') & ...
            contains(tab.timewin, contrasts{c}{4}), :);
        
        neural_data_alternators
        
        neural_data_repeaters = tab(tab.contrast == contrasts{c}{1} & ...
            strcmp(tab.var, contrasts{c}{3}) & ...
            contains(tab.roi, rois{r}) &  ...
            contains(tab.freq, freqs(v).name) & ...
            tab.session == 0 & ...
            tab.subj_idx == 0 & ...
            strcmp(tab.group, 'repeaters') & ...
            contains(tab.timewin, contrasts{c}{4}), :);
        
        neural_data_repeaters
        
        neural_data_groupdiff = tab(tab.contrast == contrasts{c}{2} & ...
            strcmp(tab.var, strcat(contrasts{c}{3}, ':group')) & ...
            contains(tab.roi, rois{r}) &  ...
            contains(tab.freq, freqs(v).name) & ...
            tab.session == 0 & ...
            tab.subj_idx == 0 & ...
            contains(tab.group, 'all') & ...
            contains(tab.timewin, contrasts{c}{4}), :);
        
        neural_data_groupdiff
        
        make_plot(neural_data_alternators, neural_data_repeaters, neural_data_groupdiff);
        print(gcf, '-dpdf', sprintf('%s/individualdiffs_c%d_%s_%s.pdf', sjdat.figsdir, ...
            contrasts{c}{1}, regexprep(rois{r}, '/', ''), freqs(v).name));
    end
    end
end

% does this hold also when subsampling?
neural_data_repeaters = tab(tab.contrast== 4 & ...
    strcmp(tab.var, 'prev_resp') & ...
    contains(tab.roi, 'wang_vfc_IPS2/3') &  ...
    contains(tab.freq, 'gamma') & ...
    tab.session == 0 & ...
    tab.subj_idx == 0 & ...
    strcmp(tab.group, 'repeaters_subsampled') & ...
    contains(tab.timewin, 'stimulus'), :);

neural_data_repeaters

% does this hold also when taking only those 'true' repeaters?
neural_data_alternators = tab(tab.contrast== 4 & ...
    strcmp(tab.var, 'prev_resp') & ...
    contains(tab.roi, 'wang_vfc_IPS2/3') &  ...
    contains(tab.freq, 'gamma') & ...
    tab.session == 0 & ...
    tab.subj_idx == 0 & ...
    strcmp(tab.group, 'true_alternators') & ...
    contains(tab.timewin, 'stimulus'), :);

neural_data_alternators

% does this hold also when taking only those 'true' repeaters?
neural_data_repeaters = tab(tab.contrast== 4 & ...
    strcmp(tab.var, 'prev_resp') & ...
    contains(tab.roi, 'wang_vfc_IPS2/3') &  ...
    contains(tab.freq, 'gamma') & ...
    tab.session == 0 & ...
    tab.subj_idx == 0 & ...
    strcmp(tab.group, 'true_repeaters') & ...
    contains(tab.timewin, 'stimulus'), :);

neural_data_repeaters

end

function make_plot(neural_data_alternators, neural_data_repeaters, neural_data_groupdiff)

% dont plot if there are no data
if height(neural_data_alternators) == 0 || height(neural_data_repeaters) == 0 || height(neural_data_groupdiff) == 0,
    return;
end

close all;

subplot(481); hold on;
plot([0 1.3], [0 0], 'k:', 'linewidth', 0.5);
cmap_3 = cbrewer('div', 'PuOr', 7);
col_rep = cmap_3(end-1, :);
col_alt = cmap_3(2, :);

% cmap = [0.7801075672866592, 0.8741945391838343, 0.9197573835143085; ...
%     0.1676124288206785, 0.12168378009569247, 0.24493209028077442];
% col_rep = cmap(2, :);
% col_alt = cmap(1, :);
% 
% cmap

% 1. plot alternators

% layout depends on significance
if neural_data_alternators.adj_p < 0.05,
    mec = [1 1 1]; % filled marker
    mfc = col_alt;
    mz = 6;
    mysigstar(gca, 0.9, neural_data_alternators.value-neural_data_alternators.ci_low*1.1, ...
        neural_data_alternators.adj_p, col_alt);
else % unfilled marker for nonsignificant
    mec = col_alt;
    mfc = [1 1 1];
    mz = 4;
end

errorbar(0.9, neural_data_alternators.value, ...
    neural_data_alternators.value-neural_data_alternators.ci_low, ...
    neural_data_alternators.ci_high-neural_data_alternators.value, ...
    'capsize', 0, 'color', col_alt, 'markerfacecolor', mfc, ...
    'markeredgecolor', mec, 'marker', 'o', 'markersize', mz);

% layout depends on significance
if neural_data_repeaters.adj_p < 0.05,
    mec = [1 1 1]; % filled marker
    mfc = col_rep;
    mz = 6;
    mysigstar(gca, 1.1, neural_data_repeaters.value-neural_data_repeaters.ci_low*1.3, ...
        neural_data_repeaters.adj_p, col_rep);
else % unfilled marker for nonsignificant
    mec = col_rep;
    mfc = [1 1 1];
    mz = 4;
end

errorbar(1.1, neural_data_repeaters.value, ...
    neural_data_repeaters.value-neural_data_repeaters.ci_low, ...
    neural_data_repeaters.ci_high-neural_data_repeaters.value, ...
    'capsize', 0, 'color', col_rep, 'markerfacecolor', mfc, ...
    'markeredgecolor', mec, 'marker', '^', 'markersize', mz);

axisNotSoTight; xlim([0.8 1.5]);

% add sigstar for difference (contrast 8)
if neural_data_groupdiff.adj_p < 0.05,
    mysigstar(gca, [0.9, 1.1], 0.01+max(get(gca, 'ylim')), ...
        neural_data_groupdiff.adj_p, [0.1 0.1 0.1]);
end

% if strcmp(neural_data_alternators.var{1}, 'prev_resp'),
%     ylabel('Effect of previous choice');
% elseif strcmp(neural_data_alternators.var{1}, 'prev_hand'),
%     ylabel('Effect of previous action');
% end

% layout
offsetAxes;
set(gca, 'xtick', [0.9, 1.2], 'xticklabel', {'IPS/PCeS   ', 'IPS/PCeS   '}, 'xticklabelrotation', -45);
ax = gca;
ax.XTickLabel{1} = sprintf('\\color[rgb]{%f,%f,%f}%s', col_alt, ax.XTickLabel{1});
ax.XTickLabel{2} = sprintf('\\color[rgb]{%f,%f,%f}%s', col_rep, ax.XTickLabel{2});
if strcmp(neural_data_alternators.freq, 'gamma'),
    title({'';''});
end
set(gca, 'fontsize', 6);
tightfig;

% set ylims to match dics_scalars_stats.m
switch neural_data_alternators.var{1}
    case 'prev_resp'
        switch neural_data_alternators.freq{1}
            case 'alpha'
                ylim([-1 2.5]);
            case 'gamma'
                ylim([-0.6 1.95]);
        end
    case 'prev_hand'
        switch neural_data_alternators.freq{1}
            case 'alpha'
                %  ylim([-2 2]);
            case 'gamma'
                ylim([-1, 1.2]);
            case 'beta'
                ylim([-1 2.2]);
        end
        %ylim([-1.5 2.9]);
end

    
end
