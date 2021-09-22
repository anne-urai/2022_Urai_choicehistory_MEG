function dics_plot_timecourses(sessions, vs, sjgr)

close all;
set(groot, 'DefaultFigureWindowStyle','normal');

if ~exist('sessions', 'var'), sessions = [0, 1:2]; end
if ischar(sessions),          sessions = str2double(sessions); end

freqs                         = dics_freqbands; % retrieve specifications
if ~exist('vs', 'var'),       vs = 1:3; end
if ischar(vs),                vs = str2double(vs); end

if ~exist('sjgr', 'var'),     sjgr = 1; end % for all sjs together
if ischar(sjgr),              sjgr = str2double(sjgr); end

sjdat = subjectspecifics('ga');

% choose some more settings

sjgroups = {'all', 'repeaters', 'alternators'};
group = sjgroups{sjgr}; % only run once, don't loop
fz = 7;
set(groot, 'defaultaxesfontsize', fz, ...
    'defaultaxestitlefontsizemultiplier', 1, 'defaultaxestitlefontweight', 'normal');

for session = sessions,
    for v = vs,
        
        % =========================================== %
        % GET PARCELLATED DATA FROM ALL SUBJECTS
        % =========================================== %
        
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
        else
            source = load(sprintf('%s/GA-S%d_parcel_%s.mat', sjdat.roidir, ...
                session, freqs(v).name));
            source = source.source;
        end
        fprintf('%s/GA-S%d_parcel_%s.mat \n', sjdat.roidir, session, freqs(v).name);
        
        % remove some ugly stuff in the beginning and between epochs
        rmidx = [1:4, 31:41, 45:48, 79:85, 123:length(source.time)];
        % rmidx = [1:4, 31:41, 45:48, 79:length(source.time)];
        source.pow(:, :, rmidx) = [];
        source.time(rmidx) = [];
        
        % REMOVE NANS FROM TIMECOURSE - make the epoch borders smaller
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
        
        % ADD SOME HISTORY VARS
        tab.prev_stim     = circshift(tab.stimulus, 1);
        tab.prev_hand     = circshift(tab.hand, 1);
        tab.prev_hand     = -1 * sign(tab.prev_hand - 15);
        tab.prev_resp     = circshift(tab.response, 1);
        tab.repeat        = 1 * (tab.prev_resp == tab.response);
        tab.repeat(tab.repeat == 0) = -1; % to allow for the same coding as other vars
        
        % remove for trials that are not continuous
        wrongtrl          = (tab.trial ~= circshift(tab.trial, 1) + 1);
        tab{wrongtrl, {'prev_stim', 'prev_resp', 'prev_hand', 'repeat'}} = nan;
        
        % =========================================== %
        % CODE FOR EACH INDIVIDUAL'S PREFERRED RESPONSE, REPEAT VS. ALTERNATE
        [gr, repetition] = findgroups(tab(:, 'subj_idx'));
        repetition.repeat = splitapply(@nanmean, tab.repeat, gr);
        repetition.repeat_zscore = zscore(repetition.repeat);
        for sj = unique(tab.subj_idx)'
            tab.repetition(tab.subj_idx == sj) = ...
                repetition.repeat(repetition.subj_idx == sj);
            tab.repetition_zscore(tab.subj_idx == sj) = ...
                repetition.repeat_zscore(repetition.subj_idx == sj);
        end
        % also split into repeaters vs alternators
        tab.group = zeros(size(tab.repetition));
        tab.group(tab.repetition < 0) = -1;
        tab.group(tab.repetition > 0) = 1;
        
        % map table idx to MEG idx
        [~, ~, tidx]    = intersect(source.trialinfo(:, 18), tab.idx, 'stable');
        assert(size(source.trialinfo, 1) == length(tidx));
        tab             = tab(tidx, :); % keep only that part of the table
        assert(isequal(tab.idx, source.trialinfo(:, 18)), 'idx do not match');
        
        % =========================================== %
        % SELECT SUBGROUPS
        % repeat is [-1, 1] so split around 0
        % =========================================== %
        
        if contains(group, 'repeaters'),
            rm_alternators = ismember(tab.subj_idx, repetition.sjidx(repetition.repeat < 0));
            tab(rm_alternators, :) = [];
            source.pow(:, rm_alternators, :) = [];
        elseif contains(group, 'alternators'),
            rm_repeaters = ismember(tab.subj_idx, repetition.sjidx(repetition.repeat > 0));
            tab(rm_repeaters, :) = [];
            source.pow(:, rm_repeaters, :) = [];
        end
        
        % =========================================== %
        % DEFINE GROUPINGS OF TRIALS THAT ARE INTERESTING TO PLOT
        % =========================================== %
        
        clear contrasts;
        [contrasts(1).g, contrasts(1).tid] = findgroups(tab(:, {'subj_idx', 'stimulus'}));
        [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'hand'}));
        [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'prev_hand'}));
        
        % some 2-way contrasts
        [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'stimulus', 'prev_resp'}));
        [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'hand', 'prev_hand'}));
        
        % repetition vs alternation
        [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'repeat'}));
        
        % for previous choice stuff - can look at post-response timecourses
        [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'response'}));
        
        % 8-9 add contrasts with a group interaction!
        [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'stimulus', 'prev_resp'}));
        [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'hand', 'prev_hand'}));
        
        % 10-11 add interaction with continuous repetition behavior
        [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'stimulus', 'prev_resp'}));
        [contrasts(end+1).g, contrasts(end+1).tid] = findgroups(tab(:, {'subj_idx', 'hand', 'prev_hand'}));
        
        % =========================================== %
        % LOOP OVER ALL CHANNELS
        % =========================================== %
        
        %         userois = [find(~cellfun(@isempty, regexp(source.label, '\w*aeu\w*lateralized\w*')))', ...
        %             find(~cellfun(@isempty, regexp(source.label, '\w*wang_vfc\w*')))'];
        %         userois = 1:length(source.label); % use all
        
        useroi_names = {'wang_vfc_V1';'wang_vfc_V2-V4';'wang_vfc_VO1/2';'wang_vfc_PHC';'wang_vfc_V3A/B'; ...
            'wang_vfc_MT/MST';'wang_vfc_LO1/2';'wang_vfc_IPS0/1';'wang_vfc_IPS2/3';'wang_vfc_IPS4/5'; ...
            'wang_vfc_SPL1';'wang_vfc_FEF'; 'aeu_symm_M1';'aeu_symm_aIPS'; ...
            'jwg_symm_aIPS';'jwg_symm_IPSPCeS';'jwg_symm_M1'; ...
            'aeu_M1_lateralized';'aeu_PreCeS_lateralized';'aeu_aIPS_lateralized'; ...
            'jwg_aIPS_lateralized';'jwg_IPS_PCeS_lateralized';'jwg_M1_lateralized'};
        useroi_names = {'wang_vfc_V3A/B', 'wang_vfc_MT/MST', 'jwg_M1_lateralized'};
        useroi_names = {'jwg_M1_lateralized'};
        userois = find(ismember(source.label, useroi_names))';
        disp(source.label(userois));
        
        for r = userois,
            for c = [3], % 5 4
                
                if c > 7 & sjgr > 1,
                    continue;
                end
                
                % group data within each individual and conditiom
                tmpdat  = splitapply(@nanmean, squeeze(source.pow(r, :, :)), contrasts(c).g);
                timeidx = source.time;
                
                % =========================================== %
                % STATS ON CONTRASTS
                % =========================================== %
                
                vars = setdiff(contrasts(c).tid.Properties.VariableNames, 'subj_idx');
                stats.names           = vars;
                
                for vx = 1:length(vars)
                    
                    [g_tmp, tid_tmp] = findgroups(tab(:, {'subj_idx', vars{vx}}));
                    tmp_contrast = splitapply(@nanmean, squeeze(source.pow(r, :, :)), g_tmp);
                    
                    % compute a contrast, average +- sem across participants
                    tmp_contrast_1 = tmp_contrast(tid_tmp.(vars{vx}) == 1, :);
                    tmp_contrast_2 = tmp_contrast(tid_tmp.(vars{vx}) == -1, :);
                    tmp_contrast_diff = tmp_contrast_1 - tmp_contrast_2;
                    
                end
                
                % stats - cluster-based permutation correction
                [h1, pval1] = ttest_clustercorr(tmp_contrast_1);
                [h2, pval2] = ttest_clustercorr(tmp_contrast_2);
                [h3, pval3] = ttest_clustercorr(tmp_contrast_1, tmp_contrast_2);
                
                % =========================================== %
                % PLOT
                % =========================================== %
                
                close all;
                if c == 1,
                    subplot(5,2,[1 2 3]); hold on;
                elseif c == 3,
                    subplot(5,4,[1 2]); hold on;
                end
                cmap = inferno(10);
                cmap = cmap([6 8], :);
                
                % THEN THE DATA ON TOP
                boundedline(1:length(timeidx), mean(tmpdat(contrasts(c).tid{:, 2} == 1, :)), ...
                    std(tmpdat(contrasts(c).tid{:, 2} == 1, :)) / sqrt(sum(contrasts(c).tid{:, 2} == 1)), ...
                    'nan', 'gap', 'cmap', cmap(1, :), 'alpha');
                boundedline(1:length(timeidx), mean(tmpdat(contrasts(c).tid{:, 2} == -1, :)), ...
                    std(tmpdat(contrasts(c).tid{:, 2} == -1, :)) / sqrt(sum(contrasts(c).tid{:, 2} == -1)), ...
                    'nan', 'gap', 'cmap', cmap(end, :), 'alpha');
                
                axis tight;
                ymin = min(get(gca, 'ylim'))-1;
                %                 plot(find(h1==1), ymin*ones(sum(h1==1)), '.', 'color', cmap(1, :), 'markerfacecolor', cmap(1, :));
                %                 plot(find(h2==1), (ymin-1)*ones(sum(h2==1)), '.', 'color', cmap(end, :),  'markerfacecolor', cmap(end, :));
                plot(find(h3==1), (ymin)*ones(sum(h3==1)), '-', 'color', [0.5 0.5 0.5],  'markerfacecolor', [0.5 0.5 0.5]);
                
                % layout
                axis tight;
                hline(0);
                plot_timename(source.time, 0.2);
                xlabel('Time (s)');
                
                switch source.label{r}
                    case 'wang_vfc_V3A/B'
                        roi_name = 'V3A/B';
                    case 'wang_vfc_MT/MST'
                        roi_name = 'MT+';
                    case  'jwg_M1_lateralized'
                        roi_name = 'M1';
                end
                
                axis tight;
                % text(min(get(gca, 'xlim'))+3, 1.2*max(get(gca, 'ylim')), roi_name, 'fontweight', 'bold', 'fontsize', 8);
                % \bfbold\rm
                ylabel({'Signal change (%)'; sprintf('\\bf\\%s\\rm-band (%d-%d Hz)', freqs(v).name, ...
                    freqs(v).freq-freqs(v).tapsmofrq, freqs(v).freq+freqs(v).tapsmofrq)}, ...
                    'interpreter', 'tex');
                offsetAxes;
                
                set(gca, 'fontsize', 6);
                tightfig;
                print(gcf, '-dpdf', sprintf('%s/dics_timecourse_c%d_%s_%s.pdf', sjdat.figsdir, ...
                    c, freqs(v).name, regexprep(source.label{r}, '/', '')));
                
                % ===========================================
                
            end % contrast
        end % roi
        
    end % freqW
end % session
