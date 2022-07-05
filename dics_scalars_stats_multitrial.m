function dics_scalars_stats_multitrial()

if ~exist('sessions', 'var'), sessions = [0]; end
if ischar(sessions),          sessions = str2double(sessions); end
statsmethods = {'glme'};

close all;
set(groot, 'DefaultFigureWindowStyle','normal', 'DefaultAxesFontSize', 3);
sjdat = subjectspecifics('ga');

freqs = dics_freqbands; % retrieve specifications
vs = 1:3;

% add repetition probability for each subject
tab2 = readtable(sprintf('%s/allsubjects_meg.csv', sjdat.csvdir));
tab2.prev_resp     = circshift(tab2.response, 1);
tab2.repeat        = 1 * (tab2.prev_resp == tab2.response);
tab2.repeat(tab2.repeat == 0) = -1; % to allow for the same coding as other vars
wrongtrl          = (tab2.trial ~= circshift(tab2.trial, 1) + 1);
tab2{wrongtrl, {'prev_stim', 'prev_resp', 'repeat'}} = nan;
[g, perf] = findgroups(tab2(:, {'subj_idx'}));
[perf.repeat] = splitapply(@nanmean, tab2.repeat, g);

% =========================================== %
% GET TABLES WITH INDIVIDUAL ESTIMATES
% =========================================== %

for v = vs,
    % filename = sprintf('S%d_%s_%s', 0, freqs(v).name, 'glme');
    tab{v} = readtable(sprintf('%s/effectsizes_%s.csv', sjdat.statsdir, freqs(v).name));
end
tab = vertcat(tab{:});
% remove duplicates
[~, ind] = unique(tab(:, {'subj_idx', 'contrast', 'formula', 'freq', ...
    'session', 'roi', 'var', 'timewin', 'group'}), 'rows');
tab = tab(ind,:);
timewins = unique(tab.timewin); % use all that are in the effectsizes csv

% FDR correction
[~, crit_p, ~, adj_p] = fdr_bh(tab.pval(~isnan(tab.pval)));
tab.adj_p = nan(size(tab.pval));
tab.adj_p(~isnan(tab.pval)) = adj_p; % use adjusted values

% match to each subject's repetition prob
for sj = unique(perf.subj_idx)'
    tab.repeat(tab.subj_idx == sj) = perf.repeat(perf.subj_idx == sj);
end
unique(tab.roi)

% ====================================================================================== %
% MAKE NICER-LOOKING BARGRAPHS
% ====================================================================================== %

userois = {'wang_vfc_IPS0/1', 'wang_vfc_IPS2/3', 'pooled_motor_lateralized'};
roinames = {'IPS0/1', 'IPS2/3', 'Motor'};
timewins = {'stimulus', 'stimulus', 'reference'};

% always use the same names
cmap_3 = cbrewer('div', 'PuOr', 7);
cmap = cmap_3([2, end-1], :);
tic;

% make things easier
tab.var = replace(tab.var, 'prev_resp', 'prev1resp');
tab.var = replace(tab.var, 'prev_hand', 'prev1hand');

for f = vs,
    for r = 1:length(roinames),
        
        groups = {'alternators', 'repeaters'};
        close all;
        subplot(441); hold on;
        plot([1, 7], [0 0], 'k:', 'linewidth', 0.5);
        
        for gridx = 1:length(groups),
            
            % grab the datapoints for each person from the table
            tmp_tab = tab(tab.contrast == 15 ...
                & endsWith(tab.group, groups{gridx}) ...
                & contains(tab.freq, freqs(f).name) ...
                & contains(tab.timewin, timewins{r}) ...
                & contains(tab.roi, userois{r}) ...
                & tab.subj_idx == 0, :);
            
            % replace 'prev_resp' with 'prev1resp' to ensure correct order!
            tmp_tab = sortrows(tmp_tab, 'var');
            
            vars = unique(tmp_tab.var);
            vars = setdiff(vars, '(Intercept)');
            assert(length(vars) > 0, 'no variables found');
            order_vars = {'prev1resp', 'prev2resp', 'prev3resp', 'prev4resp', 'prev5resp', 'prev6resp', 'prev7resp'};
            if strcmp(roinames{r}, 'Motor'),
                order_vars = regexprep(order_vars, 'resp', 'hand');
            end
            %assert(isequal(tmp_tab{ismember(tmp_tab.var, order_vars), 'var'}', order_vars));
            
            % pull out the 1:7 lags
            mn_val = tmp_tab{ismember(tmp_tab.var, order_vars), 'value'};
            p_val = tmp_tab{ismember(tmp_tab.var, order_vars), 'adj_p'};
            ci_low = mn_val - tmp_tab{ismember(tmp_tab.var, order_vars), 'ci_low'};
            ci_high = tmp_tab{ismember(tmp_tab.var, order_vars), 'ci_high'} - mn_val;
            assert(length(mn_val) == length(order_vars));
            
            % fdr correction
            %[h, crit_p, adj_ci_cvrg, adj_p] = fdr_bh(p_val, 0.05, 'pdep');
            
            % plot this
            plot(1:length(mn_val), mn_val, '-', 'color', cmap(gridx, :));
            
            for v = 1:length(mn_val),
                % layout depends on significance
                if p_val(v) < 0.05,
                    mec = [1 1 1]; % filled marker
                    mfc = cmap(gridx, :);
                    mz = 6;
                else % unfilled marker for nonsignificant
                    mec = cmap(gridx, :);
                    mfc = [1 1 1];
                    mz = 4;
                end
                markers = {'o', '^'};
                
                % plot mean +- sem
                errorbar(v + (gridx - 1.5) * 0.2, mn_val(v), ci_low(v), ci_high(v), ...
                    'capsize', 0, 'color', cmap(gridx, :), 'markerfacecolor', mfc, ...
                    'markeredgecolor', mec, 'marker', markers{gridx}, 'markersize', mz);
            end
        end
        
        % add the group difference
        group_comp = sortrows(tab(tab.contrast == 16 ...
            & endsWith(tab.group, 'all') ...
            & contains(tab.freq, freqs(f).name) ...
            & contains(tab.timewin, timewins{r}) ...
            & contains(tab.roi, userois{r}) ...
            & contains(tab.var, ':group') ...
            & tab.subj_idx == 0, :));
        %[~, crit_p_gr, ~, ~] = fdr_bh(group_comp.adj_p, 0.05, 'pdep');
        for v = 1:height(group_comp),
            if group_comp.adj_p(v) < 0.05,
                mysigstar(gca, v+0.1, (ci_high(v) + mn_val(v)) * 1.3, group_comp.adj_p(v));
            end
        end
        
        % layout
        axisNotSoTight;
        xlim([0.5 length(mn_val)+0.5]);
        xticks([1:7]);
%         if r == 1,
            ylim([-1.8 2.8]);
%         elseif r == 3,
%             ylim([-1 1]);
%         end
        offsetAxes;
        %ylabel('Effect size (\Delta%)');
        %ylabel(sprintf('%s, %s', freqs(f).name, roinames{r}));
        xlabel('Lags');
        
        tightfig;
        set(gca, 'fontsize', 6);
        print(gcf, '-dpdf', sprintf('%s/neural_lags_%s_%s.pdf', sjdat.figsdir, ...
            freqs(f).name, regexprep(roinames{r}, '/', '')));
        
        
    end
end

% 
% %% ======================================== %
% % correlate with Fruend kernels
% kernels = nan(65, 7);
% ips = nan(65, 7);
% perf.corr = nan(size(perf.subj_idx));
% perf.pval = nan(size(perf.subj_idx));
% perf.rep_eff = nan(size(perf.subj_idx));
% 
% for sj = sjdat.clean,
%     kern = readtable(sprintf('%s/%s/sj_%02d_kernels.csv', sjdat.csvdir, 'Fruend', sj));
%     kernels(sj, :) = kern.resp_kernel;
%     
%     % grab the datapoints for each person from the table
%     tmp_tab = tab(tab.contrast == 15 ...
%         & contains(tab.freq, freqs(f).name) ...
%         & endsWith(tab.group, 'all') ...
%         & contains(tab.timewin, 'stimulus') ...
%         & contains(tab.roi, userois{r})  ...
%         & tab.subj_idx == sj, :);
%     tmp_tab = sortrows(tmp_tab, 'var');
%     order_vars = {'prev1resp', 'prev2resp', 'prev3resp', 'prev4resp', 'prev5resp', 'prev6resp', 'prev7resp'};
%     assert(isequal(tmp_tab{ismember(tmp_tab.var, order_vars), 'var'}', order_vars));
%     vals = tmp_tab{ismember(tmp_tab.var, order_vars), 'value'};
%     ips(sj, :) = vals;
%     
%     % put in existing table
%     sjidx = find(perf.subj_idx == sj);
%     perf.rep_eff(sjidx) = mean(tmp_tab.repeat);
%     [perf.corr(sjidx), perf.pval(sjidx)] = corr(kernels(sj, :)', ips(sj, :)');
%     
% end
% 
% %% display summary
% 
% % [h,p,ci,stats] = ttest(perf.corr, 0)
% % [h,p,ci,stats] = ttest(perf.corr(perf.rep_eff > 0), 0)
% % [h,p,ci,stats] = ttest(perf.corr(perf.rep_eff < 0), 0)
% 
end
% 
