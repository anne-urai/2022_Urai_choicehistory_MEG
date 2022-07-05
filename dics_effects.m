function dics_effects(sessions, vs, remove_outliers, sjgrs)

addpath(genpath('~/Documents/code/Tools'));
addpath(genpath('~/code/Tools'));
addpath(('~/Documents/code/gramm'));

close all;
set(groot, 'DefaultFigureWindowStyle','normal');
sjdat = subjectspecifics('ga');

if ~exist('sessions', 'var'), sessions = [0]; end
if ischar(sessions),          sessions = str2double(sessions); end

freqs                         = dics_freqbands; % retrieve specifications
if ~exist('vs', 'var'),       vs = 1:3; end
if ischar(vs),                vs = str2double(vs); end

if ~exist('remove_outliers', 'var'),       remove_outliers = true; end % default: remove values above 500
if ischar(remove_outliers),                remove_outliers = str2double(remove_outliers); end

sjgroups = {'all', 'repeaters', 'alternators', 'repeaters_subsampled', ...
    'true_repeaters', 'true_alternators'};
% sjgroups = {'all'};
if ~exist('sjgrs', 'var'),     sjgrs = 1:3; end % for all sjs together
if ischar(sjgrs),              sjgrs = str2double(sjgrs); end
statmethod = 'glme'; % stick to this

for session = sessions,
    for v = vs,
        
        % choose some more settings
        for sjgr = sjgrs,
            group = sjgroups{sjgr}; % only run once, don't loop
            
            %% =========================================== %
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
            
            % REMOVE NANS FROM TIMECOURSE - make the epoch borders smallerf
            % for better plotting
            startSeq = strfind(squeeze(isnan(nanmean(nanmean(source.pow))))', true(1,3));
            removeidx = false(1, length(source.time));
            for s = 1:length(startSeq),
                removeidx(startSeq(s)+1 : startSeq(s)+1) = 1;
            end
            source.pow(:, :, removeidx) = [];
            source.time(removeidx) = [];
            
            %% =========================================== %
            % LINK TO BEHAVIORAL DATA TABLE
            % =========================================== %
            
            tab = readtable(sprintf('%s/allsubjects_meg.csv', sjdat.csvdir));
            tab = tab(ismember(tab.subj_idx, sjdat.clean), :);
            
            % recode hands
            tab.hand(tab.hand == 12) = -1;
            tab.hand(tab.hand == 18) = 1;
            
            % ADD SOME HISTORY VARS
            tab.prev_stim     = circshift(tab.stimulus, 1);
            tab.prev_hand     = circshift(tab.hand, 1);
            tab.prev_resp     = circshift(tab.response, 1);
            tab.prev2resp     = circshift(tab.response, 2);
            tab.prev3resp     = circshift(tab.response, 3);
            tab.prev4resp     = circshift(tab.response, 4);
            tab.prev5resp     = circshift(tab.response, 5);
            tab.prev6resp     = circshift(tab.response, 6);
            tab.prev7resp     = circshift(tab.response, 7);
           
            tab.prev1hand     = circshift(tab.hand, 1);
            tab.prev2hand     = circshift(tab.hand, 2);
            tab.prev3hand     = circshift(tab.hand, 3);
            tab.prev4hand     = circshift(tab.hand, 4);
            tab.prev5hand     = circshift(tab.hand, 5);
            tab.prev6hand     = circshift(tab.hand, 6);
            tab.prev7hand     = circshift(tab.hand, 7);
            
            % code for previous reward too
            tab.prev_correct  = circshift(tab.correct, 1);
            tab.prevresp_correct = tab.prev_resp;
            tab.prevresp_correct(tab.prev_correct == 0) = 0;
            tab.prevresp_error = tab.prev_resp;
            tab.prevresp_error(tab.prev_correct == 1) = 0;
            assert(isequaln(tab.prevresp_correct + tab.prevresp_error, tab.prev_resp));
            % tab.prev_correct(tab.prev_correct == 0) = -1; % effects coding
            tab.prev_error = abs(tab.prev_correct - 1); % code for difference with prev error
            
            % for contrast previous wrong answer only
            tab.prev_wrong = tab.prev_error;
            tab.prev_wrong(tab.prev_wrong == 0) = -1;
            
            % same for the hand, motor coding
            tab.prevhand_correct = tab.prev_hand;
            tab.prevhand_correct(tab.prev_correct == 0) = 0;
            tab.prevhand_error = tab.prev_hand;
            tab.prevhand_error(tab.prev_correct == 1) = 0;
            assert(isequaln(tab.prevhand_correct + tab.prevhand_error, tab.prev_hand));
            
            % repetition or alternation
            tab.repeat        = 1 * (tab.prev_resp == tab.response);
            tab.repeat(tab.repeat == 0) = -1; % to allow for the same coding as other vars
            
            % remove for trials that are not continuous
            wrongtrl          = (tab.trial ~= circshift(tab.trial, 1) + 1);
            tab{wrongtrl, {'prev_stim', 'prev_resp', 'prev_hand', 'repeat', ...
                'prev2resp', 'prev3resp', 'prev4resp', 'prev5resp', 'prev6resp', 'prev7resp'}} = nan;
            
            [gr, repetition] = findgroups(tab(:, 'subj_idx'));
            repetition.repeat = splitapply(@nanmean, tab.repeat, gr);
            
            repetition.repeat_zscore = zscore(repetition.repeat);
            for sj = unique(tab.subj_idx)'
                tab.repetition(tab.subj_idx == sj) = ...
                    repetition.repeat(repetition.subj_idx == sj);
                tab.repetition_zscore(tab.subj_idx == sj) = ...
                    repetition.repeat_zscore(repetition.subj_idx == sj);
            end
            
            %% =========================================== %
            % determine group splits
            % =========================================== %
            
            % use all subjects, except P39 (exactly P(repeat) at 0.5)
            tab.group = nan(size(tab.repetition));
            tab.group(tab.repetition < 0) = -1; % alternators
            tab.group(tab.repetition > 0) = 1; % repeaters
            
            % summarize and display
            rep = splitapply(@nanmean, tab.repetition, findgroups(tab.subj_idx));
            fprintf('%d repeaters, %d alternators, %d unbiased', ...
                length(find(rep > 0)), ...
                length(find(rep < 0)), ...
                length(find(rep == 0)));
            
            %% map table idx to MEG idx
            [~, ~, tidx]    = intersect(source.trialinfo(:, 18), tab.idx, 'stable');
            assert(size(source.trialinfo, 1) == length(tidx));
            tab             = tab(tidx, :); % keep only that part of the table
            assert(isequal(tab.idx, source.trialinfo(:, 18)), 'idx do not match');
            
            % =========================================== %
            % SELECT SUBGROUPS
            % repeat is [-1, 1] so split around 0
            % =========================================== %
            
            if strcmp(group, 'repeaters'),
                rm_alternators = find(tab.group == -1);
                tab(rm_alternators, :) = [];
                source.pow(:, rm_alternators, :) = [];
            elseif strcmp(group, 'repeaters_subsampled'),
                %assert(1==0);
                alternators = repetition.subj_idx(repetition.repeat < 0);
                repeaters = repetition.subj_idx(repetition.repeat > 0);
                rng(123);
                keep_repeaters = randsample(repeaters, length(alternators));
                rm_subj = ismember(tab.subj_idx, ...
                    setdiff(unique(tab.subj_idx), keep_repeaters));
                tab(rm_subj, :) = [];
                source.pow(:, rm_subj, :) = [];
            elseif strcmp(group, 'alternators'),
                rm_repeaters = find(tab.group == 1);
                tab(rm_repeaters, :) = [];
                source.pow(:, rm_repeaters, :) = [];
            elseif strcmp(group, 'true_repeaters'),
                % definition based on permuted fruend weights
                rm_subj = find(~ismember(tab.subj_idx, ...
                    [5, 13, 15, 27, 47, 51, 53, 55, 56, 57, 59, 60, 62, 63, 64]));
                % definition based on p(repeat) across blocks
                rm_subj = find(~ismember(tab.subj_idx, ...
                    [14, 32, 41, 45, 51, 53, 56, 57, 59, 60, 63, 64]));
                %                 %  p(repeat) across blocks, all sessions
                %                 rm_subj = find(~ismember(tab.subj_idx, ...
                %                     [15, 17, 19, 25, 27, 32, 36, 38, 41, 44, 45, 48, 51, 53, 54, 56, 57, 62, 63, 64, 65]));
                tab(rm_subj, :) = [];
                source.pow(:, rm_subj, :) = [];
            elseif strcmp(group, 'true_alternators'),
                % definition based on permuted fruend weights
                rm_subj = find(~ismember(tab.subj_idx, ...
                    [8, 9, 10, 18, 28, 33, 44, 49, 50, 58]));
                % definition based on p(repeat) across blocks
                rm_subj = find(~ismember(tab.subj_idx, ...
                    [5, 8, 9, 10, 12, 13, 18, 20, 30, 33, 55, 58]));
                %                 % p(repeat) across blocks, all sessions
                %                 rm_subj = find(~ismember(tab.subj_idx, ...
                %                     [2, 8, 9, 18, 28, 29, 30, 33, 42, 43, 50, 58, 61]));
                tab(rm_subj, :) = [];
                source.pow(:, rm_subj, :) = [];
            end
            
            % =========================================== %
            % DEFINE GROUPINGS OF TRIALS THAT ARE INTERESTING TO PLOT
            % =========================================== %
            
            clear contrasts;
            [contrasts(1).g, contrasts(1).tid] = findgroups(tab(:, {'subj_idx', 'stimulus', 'response'}));
            [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'stimulus', 'prev_wrong'}));
            [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'prev_hand'})); % need for motor fig
            
            % some 2-way contrasts
            [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'stimulus', 'prev_resp'})); %4 need for parietal fig
            [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'hand', 'prev_hand'})); %5 % for motor status
            
            % dependence on previous feedback
            [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', ...
                'stimulus', 'prevresp_correct', 'prevresp_error'})); % 6
            
            % dependence on previous feedback
            [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'hand', ...
                'prevhand_correct', 'prevhand_error'}));
            
            % 8-9 add contrasts with a group interaction!
            [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'stimulus', 'prev_resp'})); % 8
            [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'hand', 'prev_hand'})); %9
            
            % 10-11 add interaction with continuous repetition behavior
            [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'stimulus', 'prev_resp'})); %10
            [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'hand', 'prev_hand'})); %11
            
            % interaction term
            [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'stimulus', 'prev_resp'})); % 12
            
            % interaction with prevfeedback
            [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'stimulus', ...
                'prev_resp', 'prev_correct'})); % 13
            
            [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'stimulus', ...
                'prev_resp', 'prev_error'})); % 14
            
            [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'stimulus', ...
                'prev_resp', 'prev2resp', 'prev3resp', 'prev4resp', 'prev5resp', 'prev6resp', 'prev7resp'})); % 15
            
            % group interaction
            [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'stimulus', ...
                'prev_resp', 'prev2resp', 'prev3resp', 'prev4resp', 'prev5resp', 'prev6resp', 'prev7resp'})); % 16
            
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
            
            useroi_names = {'glasser_premotor_lateralized_PMd/v';'glasser_premotor_symm_PMd/v';'jwg_IPS_PCeS_lateralized'; ...
                'jwg_M1_lateralized';'jwg_aIPS_lateralized';'jwg_symm_IPSPCeS';'jwg_symm_M1';'jwg_symm_aIPS'; ...
                'wang_vfc_IPS0/1';'wang_vfc_IPS2/3';'wang_vfc_MT/MST';'wang_vfc_V1';'wang_vfc_V2-V4';'wang_vfc_V3A/B'; ...
                'wang_vfc_lat_lateralized_IPS0/1';'wang_vfc_lat_lateralized_IPS2/3';'wang_vfc_lat_lateralized_MT/MST'; ...
                'wang_vfc_lat_lateralized_V1';'wang_vfc_lat_lateralized_V2-V4';'wang_vfc_lat_lateralized_V3A/B'; ...
                'pooled_motor_lateralized'};
            useroi_names = {'wang_vfc_IPS2/3', 'wang_vfc_IPS0/1', 'pooled_motor_lateralized'};
            % useroi_names = {'pooled_motor_lateralized'}
            userois = find(ismember(source.label, useroi_names))';
            % userois = 1:length(source.label);
            disp(source.label(userois));
            
            for r = userois,
                % contrasts with group split: 8, 9, 10, 11, 16
                for c = 4; %[8, 9]; %[4, 5]; %[8, 9, 10, 11, 16], %15; %[1, 4, 5, 8, 9, 12],
                    
                    tic;
                    % dont run for subgroups if that's the statistic we're
                    % testing for
                    if sjgr > 1 && ismember(c, [8, 9, 10, 11, 16]),
                        continue;
                    end
                    
                    % =========================================== %
                    % STATS ON CONTRASTS
                    % =========================================== %
                    
                    clear stats;
                    
                    % DETERMINE GLME FORMULA
                    if c == 12, % interaction between stimulus and prevresp
                        formula         = sprintf('neural_data ~ 1 + %s*%s + (1|subj_idx)', ...
                            contrasts(c).tid.Properties.VariableNames{2}, ...
                            contrasts(c).tid.Properties.VariableNames{3});
                    elseif c == 13 || c == 14, % interaction between prevresp and prevfeedback
                        formula         = sprintf('neural_data ~ 1 + %s + %s*%s + (1|subj_idx)', ...
                            contrasts(c).tid.Properties.VariableNames{2}, ...
                            contrasts(c).tid.Properties.VariableNames{3}, ...
                            contrasts(c).tid.Properties.VariableNames{4});
                    elseif c == 10 || c == 11,
                        formula = sprintf('neural_data ~ 1 + %s + %s*repetition+ (1|subj_idx)', ...
                            contrasts(c).tid.Properties.VariableNames{2}, ...
                            contrasts(c).tid.Properties.VariableNames{3});
                    elseif c == 8 || c == 9, % split by group
                        % 'neural ~ 1 + stimulus + prev_resp*group + (1|subj_idx)'
                        formula = sprintf('neural_data ~ 1 + %s + %s:group + (1|subj_idx)', ...
                            contrasts(c).tid.Properties.VariableNames{2}, ...
                            contrasts(c).tid.Properties.VariableNames{3});
                    elseif c == 15,
                        formula         = sprintf('neural_data ~ 1 + %s + %s + %s + %s + %s + %s + %s + %s + (1|subj_idx)', ...
                            contrasts(c).tid.Properties.VariableNames{2}, ...
                            contrasts(c).tid.Properties.VariableNames{3}, ...
                            contrasts(c).tid.Properties.VariableNames{4}, ...
                            contrasts(c).tid.Properties.VariableNames{5}, ...
                            contrasts(c).tid.Properties.VariableNames{6}, ...
                            contrasts(c).tid.Properties.VariableNames{7}, ...
                            contrasts(c).tid.Properties.VariableNames{8}, ...
                            contrasts(c).tid.Properties.VariableNames{9});
                        if strcmp(source.label{r}, 'pooled_motor_lateralized'),
                            formula = regexprep(formula, 'resp', 'hand');
                        end
                    elseif c == 16,
                        formula         = sprintf('neural_data ~ 1 + %s + %s:group + %s:group + %s:group + %s:group + %s:group + %s:group + %s:group + (1|subj_idx)', ...
                            contrasts(c).tid.Properties.VariableNames{2}, ...
                            contrasts(c).tid.Properties.VariableNames{3}, ...
                            contrasts(c).tid.Properties.VariableNames{4}, ...
                            contrasts(c).tid.Properties.VariableNames{5}, ...
                            contrasts(c).tid.Properties.VariableNames{6}, ...
                            contrasts(c).tid.Properties.VariableNames{7}, ...
                            contrasts(c).tid.Properties.VariableNames{8}, ...
                            contrasts(c).tid.Properties.VariableNames{9});
                        if strcmp(source.label{r}, 'pooled_motor_lateralized'),
                            formula = regexprep(formula, 'resp', 'hand');
                        end
                        % then the normal parsing
                    elseif width(contrasts(c).tid) == 2
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
                    else
                        assert(1==0, 'this contrast is not well defined!');
                    end
                    disp(formula);
                    
                    % =========================================== %
                    % save each fit into a new table
                    % ===========================================
                    
                    sj_effect_sizes = struct();
                    tcnt = 0;
                    
                    for tw = 1:length(timewins),
                        
                        % compute summary stats for this timewin
                        tab.neural_data = squeeze(nanmean(source.pow(r, :, timewins(tw).samples), 3))';
                        
                        % REMOVE OUTLIERS BEFORE FIT
                        if remove_outliers,
                            tab{tab.neural_data > 500, 'neural_data'} = nan;
                        end
                        
                        % the model sometimes fails
                        glme = fitglme(tab, formula);

                        % save a few things
                        coeff = glme.Coefficients;
                        formul = glme.Formula.char;
                        coeffnames = glme.CoefficientNames;
                        
                        % SAVE INTO A LARGE TABLE
                        for vx = 1:length(coeffnames)
                            
                            tcnt = tcnt + 1;
                            % save glme data
                            sj_effect_sizes(tcnt).subj_idx       = 0;
                            sj_effect_sizes(tcnt).group          = group;
                            sj_effect_sizes(tcnt).contrast       = c;
                            sj_effect_sizes(tcnt).formula        = formul;
                            sj_effect_sizes(tcnt).freq           = freqs(v).name;
                            sj_effect_sizes(tcnt).session        = session;
                            sj_effect_sizes(tcnt).roi            = source.label{r};
                            sj_effect_sizes(tcnt).var            = coeffnames{vx};
                            sj_effect_sizes(tcnt).timewin        = timewins(tw).name;
                            sj_effect_sizes(tcnt).value          = coeff.Estimate(vx);
                            sj_effect_sizes(tcnt).ci_low         = coeff.Lower(vx);
                            sj_effect_sizes(tcnt).ci_high        = coeff.Upper(vx);
                            sj_effect_sizes(tcnt).pval           = coeff.pValue(vx);
                            
                            % =========================================== %
                            % SAVE INDIVIDUAL EFFECT SIZES
                            % ==========================================
                            
                            % skip individual estimates for models with a group term
                            if ~ismember(coeffnames{vx}, tab.Properties.VariableNames) || c > 5, ...
                                    continue
                            end
                            
                            if 1,
                                % now compute subject specific estimates
                                [g_tmp, tid_tmp] = findgroups(tab(:, {'subj_idx', coeffnames{vx}}));
                                tmp_contrast = splitapply(@nanmean, squeeze(source.pow(r, :, :)), g_tmp);
                                tmp_contrast = tmp_contrast(tid_tmp.(coeffnames{vx}) == 1, :) - ...
                                    tmp_contrast(tid_tmp.(coeffnames{vx}) == -1, :);
                                
                                % also insert values for each subject
                                subjects = unique(tab.subj_idx);
                                for sj = 1:length(subjects),
                                    
                                    tcnt = tcnt + 1;
                                    sj_effect_sizes(tcnt).subj_idx       = subjects(sj);
                                    sj_effect_sizes(tcnt).group          = group;
                                    sj_effect_sizes(tcnt).contrast       = c;
                                    sj_effect_sizes(tcnt).formula        = formul;
                                    sj_effect_sizes(tcnt).freq           = freqs(v).name;
                                    sj_effect_sizes(tcnt).session        = session;
                                    sj_effect_sizes(tcnt).roi            = source.label{r};
                                    sj_effect_sizes(tcnt).var            = coeffnames{vx};
                                    sj_effect_sizes(tcnt).timewin        = timewins(tw).name;
                                    sj_effect_sizes(tcnt).value          = nanmean(tmp_contrast(sj,  ...
                                        timewins(tw).samples));
                                    sj_effect_sizes(tcnt).pval           = nan;
                                    sj_effect_sizes(tcnt).ci_low         = nan;
                                    sj_effect_sizes(tcnt).ci_high        = nan;
                                    
                                end
                            end
                        end
                        
                        % ======= regression model per subject
                        if c == 15,
                            
                            subjects = unique(tab.subj_idx);
                            for sj = 1:length(subjects),
                                disp('single-subject regression model');
                                mdl = fitglme(tab(tab.subj_idx == subjects(sj), :), ...
                                    strrep(formula, '+ (1|subj_idx)', ''));
                                coeff = mdl.Coefficients;
                                formul = mdl.Formula.char;
                                coeffnames = mdl.CoefficientNames;
                                
                                for vx = 1:length(coeffnames)
                                    tcnt = tcnt + 1;
                                    sj_effect_sizes(tcnt).subj_idx       = subjects(sj);
                                    sj_effect_sizes(tcnt).group          = group;
                                    sj_effect_sizes(tcnt).contrast       = c;
                                    sj_effect_sizes(tcnt).formula        = formul;
                                    sj_effect_sizes(tcnt).freq           = freqs(v).name;
                                    sj_effect_sizes(tcnt).session        = session;
                                    sj_effect_sizes(tcnt).roi            = source.label{r};
                                    sj_effect_sizes(tcnt).var            = coeffnames{vx};
                                    sj_effect_sizes(tcnt).timewin        = timewins(tw).name;
                                    sj_effect_sizes(tcnt).value          = coeff.Estimate(vx);
                                    sj_effect_sizes(tcnt).pval           = nan;
                                    sj_effect_sizes(tcnt).ci_low         = nan;
                                    sj_effect_sizes(tcnt).ci_high        = nan;
                                end
                            end
                        end
                    end
                    
                    % =========================================== SAVE
                    
                    writetable(struct2table(sj_effect_sizes), ...
                        sprintf('%s/GrandAverage/Stats/dics_effects/effects_S%d_%s_%s_contrast%d_%s.csv', ...
                        sjdat.path, session, freqs(v).name, regexprep(source.label{r}, '/', ''), c, group));
                    fprintf('%s/Figures/S%d_%s_%s_contrast%d_%s.csv \n', ...
                        sjdat.path, session, freqs(v).name, regexprep(source.label{r}, '/', ''), c, group);
                    toc;
                    
                end % contrast
            end % roi
        end
        
    end % freq
end % session

disp('DON''T FORGET TO APPEND FILES FOR BEFORE PLOTTING!!!');
end % function
