function dics_plot_effect_timecourses(sessions, vs, remove_outliers, sjgrs)

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

sjgroups = {'all', 'repeaters', 'alternators', 'repeaters_subsampled'};
sjgroups = {'repeaters', 'alternators'}; % do this first
if ~exist('sjgrs', 'var'),     sjgrs = 1:length(sjgroups); end % for all sjs together
if ischar(sjgrs),              sjgrs = str2double(sjgrs); end
statmethod = 'glme'; % stick to this

for session = sessions,
    for v = vs,
        
        % choose some more settings
        for sjgr = sjgrs,
            group = sjgroups{sjgr}; % only run once, don't loop
            
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
           
            %% summarize
            rep = splitapply(@nanmean, tab.repetition, findgroups(tab.subj_idx));
            fprintf('%d repeaters, %d alternators, %d unbiased', ...
                length(find(rep > 0)), ...
                length(find(rep < 0)), ...
                length(find(rep == 0)));
            
            % map table idx to MEG idx
            [~, ~, tidx]    = intersect(source.trialinfo(:, 18), tab.idx, 'stable');
            assert(size(source.trialinfo, 1) == length(tidx));
            tab             = tab(tidx, :); % keep only that part of the table
            assert(isequal(tab.idx, source.trialinfo(:, 18)), 'idx do not match');
            
            % =========================================== %
            % SELECT SUBGROUPS
            % repeat is [-1, 1] so split around 0
            % =========================================== %
            
            if strcmp(group, 'repeaters'),
                rm_alternators = find(tab.group < 1);
                tab(rm_alternators, :) = [];
                source.pow(:, rm_alternators, :) = [];
            elseif strcmp(group, 'repeaters_subsampled'),
                alternators = repetition.subj_idx(repetition.repeat < 0);
                repeaters = repetition.subj_idx(repetition.repeat > 0);
                rng(123);
                keep_repeaters = randsample(repeaters, length(alternators));
                rm_subj = ismember(tab.subj_idx, ...
                    setdiff(unique(tab.subj_idx), keep_repeaters));
                tab(rm_subj, :) = [];
                source.pow(:, rm_subj, :) = [];
            elseif strcmp(group, 'alternators'),
                rm_repeaters = find(tab.group > -1);
                tab(rm_repeaters, :) = [];
                source.pow(:, rm_repeaters, :) = [];
            end
            
            fprintf('\n\n%s: %d subjects\n', group, length(unique(tab.subj_idx)));

                       
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
            
            useroi_names = {'wang_vfc_IPS2/3', 'wang_vfc_IPS0/1', 'pooled_motor_lateralized'};
            useroi_names = {'pooled_motor_lateralized'};

            userois = find(ismember(source.label, useroi_names))';
            disp(source.label(userois));
            
            for r = userois,
                
                % match the colors for IPS01 and IPS23
                cmap = viridis(11);
                if r == 11,
                    cmap = cmap(5, :);
                elseif r == 12,
                    cmap = cmap(5, :);
                else
                    cmap = cmap(end-1, :);
                end
                
                for c = 3; %[2, 3, 5],
                    
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
                    stats.beta     = nan(num_b, length(timeidx));
                    stats.ci_low   = nan(num_b, length(timeidx));
                    stats.ci_high  = nan(num_b, length(timeidx));
                    stats.pval     = nan(num_b, length(timeidx));
                    
                    % LOOP OVER TIME
                    for tp = 1:length(timeidx)
                        
                        % grab single-trial data at this timepoint
                        tab.neural_data = squeeze(source.pow(r, :, tp))';
                        % remove outliers
                        if remove_outliers,
                            tab{tab.neural_data > 500, 'neural_data'} = nan;
                        end
                        
                        if all(isnan(tab.neural_data)), continue; end
                        
                        % actual fit, this takes a while
                        glme = fitglme(tab, formula);
                        coeff = glme.Coefficients;
                        
                        % save for plotting - skip the Intercept
                        stats.beta(:, tp)     = coeff.Estimate(2:end);
                        stats.pval(:, tp)     = coeff.pValue(2:end);
                        stats.ci_low(:, tp)   = coeff.Lower(2:end);
                        stats.ci_high(:, tp)  = coeff.Upper(2:end);
                    end
                    stats.names           = glme.CoefficientNames(2:end);
                    
                    % FDR correction
                    [~, crit_p]     = fdr_bh(stats.pval(:), 0.05);
                    crit_p = 0.01;
                    
                    % only plot points for significant timewindows, for two contrasts
                    stats.b_h = stats.beta;
                    stats.b_h(stats.pval > min(crit_p, 0.05)) = nan;
                    
                    % =========================================== %
                    % PLOT AGAIN WITHOUT GRAMM
                    % =========================================== %
                    
                    for bidx = 1:num_b,
                        
                        close all;
                        %subplot(3,3,[1 2]); hold on;
                        subplot(5,8,[1 2 3]); hold on;
                        % cmap = inferno(10);
                        
                        % THEN THE DATA ON TOP - npoint x nside x nline
                        boundedline(1:length(timeidx), stats.beta(bidx, :), ...
                            permute(cat(3, stats.beta(bidx, :) - stats.ci_low(bidx, :), ...
                            stats.ci_high(bidx, :) - stats.beta(bidx, :)), [2 3 1]), ...
                            'nan', 'gap', 'cmap', cmap, 'alpha');
                        
                        axis tight;
                        ymin = min(get(gca, 'ylim'))-1;
                        plot(1:length(timeidx), stats.b_h(bidx, :), '.', 'color', ...
                            cmap, 'markerfacecolor', cmap, 'markersize', 8);
                        
                        % layout
                        axis tight;
                        hline(0);
                        plot_timename(source.time, 0.2);
                        % xlabel('Time (s)');
                        
                        axis tight;
                        %                         ylabel({'Effect size (\Delta%)'; sprintf('effect of %s', stats.names{bidx}); ...
                        %                             sprintf('in \\bf\\%s\\rm-band (%d-%d Hz)', freqs(v).name, ...
                        %                             freqs(v).freq-freqs(v).tapsmofrq, freqs(v).freq+freqs(v).tapsmofrq)}, ...
                        %                             'interpreter', 'tex');
                        offsetAxes;
                        
                        set(gca, 'fontsize', 6);
                        switch source.label{r}
                            case 'wang_vfc_IPS0/1'
                                ylim([-2.5 3]); % set manually for different subplots
                            case 'wang_vfc_IPS2/3'
                                ylim([-1 1.8]); % set manually for different subplots
                            case 'pooled_motor_lateralized'
                                if c == 3,
                                    ylim([-1, 1]);
                                end
                        end
                        
                        tightfig;
                        print(gcf, '-dpdf', sprintf('%s/dics_effect_timecourse_c%d_%s_%s_%s_%s.pdf', sjdat.figsdir, ...
                            c, freqs(v).name, regexprep(source.label{r}, '/', ''), group, stats.names{bidx}));
                    end
                    
                end % contrast
            end % roi
        end
        
    end % freq
end % session
end % function
