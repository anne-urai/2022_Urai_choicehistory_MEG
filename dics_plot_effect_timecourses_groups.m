function dics_plot_effect_timecourses_groups(sessions, vs, remove_outliers)

addpath(genpath('~/Documents/code/Tools'));
addpath(genpath('~/code/Tools'));
addpath(('~/Documents/code/gramm'));

close all;
set(groot, 'DefaultFigureWindowStyle', 'normal');
sjdat = subjectspecifics('ga');

if ~exist('sessions', 'var'), sessions = [0]; end
if ischar(sessions),          sessions = str2double(sessions); end

freqs                         = dics_freqbands; % retrieve specifications
if ~exist('vs', 'var'),       vs = 1:3; end
if ischar(vs),                vs = str2double(vs); end

if ~exist('remove_outliers', 'var'),       remove_outliers = true; end % default: remove values above 500
if ischar(remove_outliers),                remove_outliers = str2double(remove_outliers); end

for session = sessions,
    for v = vs,
        
        % =========================================== %
        % GET PARCELLATED DATA FROM ALL SUBJECTS
        % =========================================== %
        
        disp('loading neural data...');
        if session == 0, % combine the two sessions
            source = load(sprintf('%s/GA-S%d_parcel_%s.mat', sjdat.roidir, ...
                1, freqs(v).name));
            source = source.source;
            source2 = load(sprintf('%s/GA-S%d_parcel_%s.mat', sjdat.roidir, ...
                2, freqs(v).name));
            assert(isequal(source2.source.label, source.label));
            source.pow = cat(2, source.pow, source2.source.pow);
            source.trialinfo = cat(1, source.trialinfo, source2.source.trialinfo);
            clear source2
        else % load each session separately
            source = load(sprintf('%s/GA-S%d_parcel_%s.mat', sjdat.roidir, ...
                session, freqs(v).name));
            source = source.source;
        end
        fprintf('%s/GA-S%d_parcel_%s.mat \n', sjdat.roidir, session, freqs(v).name);
        
        % hack: pool 3 motor signatures
        motor_pool = contains(source.label, {'M1_lateralized', 'glasser_premotor_lateralized_PMd/v', 'jwg_IPS_PCeS_lateralized'});
        source.label{end+1} = 'pooled_motor_lateralized';
        source.pow(end+1, :, :) = mean(source.pow(motor_pool, :, :));
        
        % remove some ugly stuff in the beginning and between epochs
        if session ~= 5,
            rmidx = [1:4, 31:41, 45:48, 79:85, 123:length(source.time)];
            source.pow(:, :, rmidx) = [];
            source.time(rmidx) = [];
        end
        
        % REMOVE NANS FROM TIMECOURSE - make the epoch borders smaller
        % for better plotting
        startSeq = strfind(squeeze(isnan(nanmean(nanmean(source.pow))))', true(1,3));
        removeidx = false(1, length(source.time));
        for s = 1:length(startSeq),
            removeidx(startSeq(s)+1 : startSeq(s)+1) = 1;
        end
        source.pow(:, :, removeidx) = [];
        source.time(removeidx) = [];
        
        % =========================================== %
        % LINK TO BEHAVIORAL DATA TABLE
        % =========================================== %
        
        tab = readtable(sprintf('%s/allsubjects_meg.csv', sjdat.csvdir));
        
        % map table idx to MEG idx
        [~, ~, tidx]    = intersect(source.trialinfo(:, 18), tab.idx, 'stable');
        assert(size(source.trialinfo, 1) == length(tidx));
        tab             = tab(tidx, :); % keep only that part of the table
        assert(isequal(tab.idx, source.trialinfo(:, 18)), 'idx do not match');
        
        % =========================================== %
        % DEFINE GROUPINGS OF TRIALS THAT ARE INTERESTING TO PLOT
        % =========================================== %
        
        clear contrasts;
        [contrasts(1).g, contrasts(1).tid] = findgroups(tab(:, {'subj_idx', 'stimulus', 'response'}));
        [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'response', 'prev_resp'}));
        [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'stimulus', 'prev_stim'})); % need for motor fig
        
        % some 2-way contrasts
        [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'stimulus', 'prev_resp'})); %4 need for parietal fig
        [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'hand', 'prev_hand'})); %5 % for motor status
        
        % contrast 6: 4 terms for timecourses
        [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'stimulus', 'response', ...
            'prev_stim', 'prev_resp'}));
        
        % define time epochs
        timewins(1).name        = 'pre_ref_time';
        timewins(1).samples     = 1:8; % pre-reference fixation to 50ms after reference onset
        timewins(end+1).name    = 'pre_stim_time';
        timewins(end).samples   = 29:36; % pre-stimulus fixation to 50ms after stimulus onset
        timewins(end+1).name    = 'reference';
        timewins(end).samples   = 7:22; % 0-750 ms after reference onset
        timewins(end+1).name    = 'stimulus';
        timewins(end).samples   = 35:51; % 0-750 ms after stimulus onset
        
        % =========================================== %
        % LOOP OVER ALL CHANNELS
        % =========================================== %
        
        % subselect which contrasts and ROIs to run per frequency, to avoid
        % that this script takes forever
        switch v
            case 1
                useroi_names = {'wang_vfc_IPS0/1'};
                use_contrasts = 2;
                thisylim = [-4.5, 4.8];
                ystep = 0.4;
            case 2
                useroi_names = {'pooled_motor_lateralized'};
                use_contrasts = 5;
                thisylim = [-9, 14];
                ystep = 1;
            case 3
                useroi_names = {'wang_vfc_IPS2/3'};
                use_contrasts = 2;
                thisylim = [-1.5, 2];
                ystep = 0.2;
        end
        userois = find(ismember(source.label, useroi_names))';
        disp(source.label(userois));
        
        for r = userois,            
            for c = use_contrasts,
                
                % =========================================== %
                % STATS ON CONTRASTS
                % =========================================== %
                
                clear stats;
                
                % DETERMINE GLME FORMULA
                if width(contrasts(c).tid) == 2
                    formula         = sprintf('neural_data ~ 1 + %s + (1|subj_idx)', ...
                        contrasts(c).tid.Properties.VariableNames{2});
                elseif width(contrasts(c).tid) == 3
                    formula         = sprintf('neural_data ~ 1 + %s + %s + (1|subj_idx)', ...
                        contrasts(c).tid.Properties.VariableNames{2}, ...
                        contrasts(c).tid.Properties.VariableNames{3});
                elseif width(contrasts(c).tid) == 4
                    formula         = sprintf('neural_data ~ 1 + %s + %s + %s + (1|subj_idx)', ...
                        contrasts(c).tid.Properties.VariableNames{2}, ...
                        contrasts(c).tid.Properties.VariableNames{3}, ...
                        contrasts(c).tid.Properties.VariableNames{4});
                elseif width(contrasts(c).tid) == 5
                    formula         = sprintf('neural_data ~ 1 + %s + %s + %s + %s + (1|subj_idx)', ...
                        contrasts(c).tid.Properties.VariableNames{2}, ...
                        contrasts(c).tid.Properties.VariableNames{3}, ...
                        contrasts(c).tid.Properties.VariableNames{4}, ...
                        contrasts(c).tid.Properties.VariableNames{5});
                else
                    assert(1==0, 'this contrast is not well defined!');
                end
                disp(formula);
                
                % =========================================== %
                % LOOP OVER TIMECOURSE
                % =========================================== %
                
                if c > 7,
                    num_b = width(contrasts(c).tid) - 1 + 2;
                else
                    num_b = width(contrasts(c).tid) - 1;
                end
                timeidx        = source.time;
                stats.beta     = nan(num_b, length(timeidx), 3);
                stats.ci_low   = nan(num_b, length(timeidx), 3);
                stats.ci_high  = nan(num_b, length(timeidx), 3);
                stats.pval     = nan(num_b, length(timeidx), 3);
                
                % LOOP OVER TIME
                for tp = 1:length(timeidx)
                    
                    % compare the two groups
                    sjgroups = {'alternators', 'repeaters'}; % do this first
                    for gridx = 1:2,
                        group = sjgroups{gridx};
                        
                        % grab single-trial data at this timepoint
                        tab.neural_data = squeeze(source.pow(r, :, tp))';
                        % remove outliers
                        if remove_outliers,
                            tab{tab.neural_data > 500, 'neural_data'} = nan;
                        end
                        
                        % =========================================== %
                        % SELECT SUBGROUPS
                        % repeat is [-1, 1] so split around 0
                        % =========================================== %
                        
                        if strcmp(group, 'repeaters'),
                            rm_alternators = find(tab.group < 1);
                            tab{rm_alternators, 'neural_data'} = nan;
                        elseif strcmp(group, 'alternators'),
                            rm_repeaters = find(tab.group > -1);
                            tab{rm_repeaters, 'neural_data'} = nan;
                        end
                        if all(isnan(tab.neural_data)), continue; end
                        
                        % actual fit, this takes a while
                        glme = fitglme(tab, formula);
                        coeff = glme.Coefficients;
                        
                        % save for plotting - skip the Intercept
                        stats.beta(:, tp, gridx)     = coeff.Estimate(2:end);
                        stats.pval(:, tp, gridx)     = coeff.pValue(2:end);
                        stats.ci_low(:, tp, gridx)   = coeff.Lower(2:end);
                        stats.ci_high(:, tp, gridx)  = coeff.Upper(2:end);
                    end
                    
                    % now directly compare the two groups
                    tab.neural_data = squeeze(source.pow(r, :, tp))';
                    % remove outliers
                    if remove_outliers,
                        tab{tab.neural_data > 500, 'neural_data'} = nan;
                    end
                    if all(isnan(tab.neural_data)), continue; end
                    
                    % actual fit, this takes a while
                    switch c
                        case 2
                            formula_2 = 'neural_data ~ 1 + response*group + prev_resp*group + (1|subj_idx)';
                        case 5
                            formula_2 = 'neural_data ~ 1 + hand*group + prev_hand*group + (1|subj_idx)';
                    end
                    
                    glme2 = fitglme(tab, formula_2);
                    coeff = glme2.Coefficients;
                    
                    % save for plotting - skip the Intercept
                    stats.beta(:, tp, 3)     = coeff.Estimate(end-1:end);
                    stats.pval(:, tp, 3)     = coeff.pValue(end-1:end);
                    stats.ci_low(:, tp, 3)   = coeff.Lower(end-1:end);
                    stats.ci_high(:, tp, 3)  = coeff.Upper(end-1:end);
                    
                end
                stats.names           = glme.CoefficientNames(2:end);
                
                % FDR correction
                [h_all, crit_p, ~, stats.adj_p] = fdr_bh(stats.pval, 0.05);
                %crit_p = 0.01;
                
                % only plot points for significant timewindows, for two contrasts
                stats.b_h = stats.beta;
                stats.b_h(stats.adj_p > 0.05) = nan;
                
                % =========================================== %
                % PLOT AGAIN WITHOUT GRAMM
                % =========================================== %
                
                for bidx = 1:num_b,
                    
                    close all;
                    %subplot(3,3,[1 2]); hold on;
                    subplot(5,8,[1 2 3]); hold on;
                    cmap_3 = cbrewer('div', 'PuOr', 7);
                    cmap = cmap_3([2, end-1], :);

                    % loop over groups
                    for gridx = 1:2,
                        % THEN THE DATA ON TOP - npoint x nside x nline
                        boundedline(1:length(timeidx), stats.beta(bidx, :, gridx), ...
                            permute(cat(3, stats.beta(bidx, :, gridx) - stats.ci_low(bidx, :, gridx), ...
                            stats.ci_high(bidx, :, gridx) - stats.beta(bidx, :, gridx)), [2 3 1]), ...
                            'nan', 'gap', 'cmap', cmap(gridx, :), 'alpha');
                        plot(1:length(timeidx), stats.b_h(bidx, :, gridx), '.', 'color', ...
                           cmap(gridx, :), 'markerfacecolor', cmap(gridx, :), 'markersize', 8);
                    end
                    
                    % show significance with bars
                    
                    axis tight;
                    set(gca, 'ylim', thisylim);
                    % repeaters
                    ymin = min(get(gca, 'ylim'))+ystep*2.2;
                    h3 = h_all(bidx, :, 1);
                    plot(find(h3==1), (ymin)*ones(sum(h3==1)), '.', 'color', cmap(1, :), ...
                        'markerfacecolor', cmap(1, :), 'markersize', 7);
                    
                    % alternators
                    ymin = ymin - ystep;
                    %if v == 2 & bidx == 1, ymin = ymin - ystep; end
                    h3 = h_all(bidx, :, 2);
                    plot(find(h3==1), (ymin)*ones(sum(h3==1)), '.', 'color', cmap(2, :), ...
                        'markerfacecolor', cmap(2, :), 'markersize', 7);
                    
                    % also indicate the difference between groups
                    ymin = ymin - ystep;
                    %if v == 2 & bidx == 1, ymin = ymin - ystep; end
                    h3 = h_all(bidx, :, 3);
                    plot(find(h3==1), (ymin)*ones(sum(h3==1)), '.', 'color', [0.1 0.1 0.1], ...
                        'markerfacecolor', [0.1 0.1 0.1], 'markersize', 7);
                    
                    %ymin = min(get(gca, 'ylim'))-1;
                    % layout
                    % axis tight;
                    hline(0);
                    plot_timename(source.time, 0.2);
                    offsetAxes;
                    
                    set(gca, 'fontsize', 6);
                    tightfig;
                    print(gcf, '-dpdf', sprintf('%s/dics_effect_timecoursegroups_c%d_%s_%s_%s_%s.pdf', sjdat.figsdir, ...
                        c, freqs(v).name, regexprep(source.label{r}, '/', ''), stats.names{bidx}));
                    
                end
                
            end % contrast
        end % roi
        
    end % freq
end % session
end % function
