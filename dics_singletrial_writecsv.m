function dics_singletrial_writecsv

close all;
sjdat = subjectspecifics('ga');

% userois = {'wang_vfc_IPS2/3', 'jwg_symm_M1', 'jwg_M1_lateralized', ...
%     'wang_vfc_V3A/B', 'wang_vfc_IPS0/1', ...
%     'glasser_premotor_lateralized_PMdv', 'jwg_IPS_PCeS_lateralized', 'jwg_aIPS_lateralized'};

userois = {'wang_vfc_lat_lateralized_V1', 'wang_vfc_lat_lateralized_V2-V4', ...
    'wang_vfc_lat_lateralized_MT/MST', 'wang_vfc_lat_lateralized_V3A/B',  'wang_vfc_lat_lateralized_IPS0/1', ...
    'wang_vfc_lat_lateralized_IPS2/3',  'jwg_aIPS_lateralized', ...
    'jwg_IPS_PCeS_lateralized', 'glasser_premotor_lateralized_PMd/v', 'jwg_M1_lateralized', ...
    'wang_vfc_V1', 'wang_vfc_V2-V4', ...
    'wang_vfc_MT/MST', 'wang_vfc_V3A/B',  'wang_vfc_IPS0/1', ...
    'wang_vfc_IPS2/3', 'jwg_symm_aIPS', ...
    'jwg_symm_IPSPCeS', 'glasser_premotor_symm_PMd/v', 'jwg_symm_M1'} ;

roinames = {'v1_lat', 'v2v4_lat', 'mtmst_lat', 'v3ab_lat', 'ips01_lat', ...
    'ips23_lat', 'aips_lat', 'pces_lat', 'pmdv_lat', 'm1_lat', ...
    'v1', 'v2v4', 'mtmst', 'v3ab', 'ips01', 'ips23', 'aips', ...
    'pces', 'pmdv', 'm1'};
    
freqs = dics_freqbands; % retrieve specifications

%% ==
for f = 1:3; %length(freqs),
    
    % =========================================== %
    % LINK TO BEHAVIORAL DATA TABLE
    % =========================================== %
    
    tab = readtable(sprintf('%s/allsubjects_meg.csv', sjdat.csvdir));
    
    % =========================================== %
    % GET PARCELLATED DATA FROM ALL SUBJECTS
    % =========================================== %
    
    disp(freqs(f).name);
    clear source source2 sourcescalars;
    sourcescalars = struct();
    
    % APPEND SESSIONS
    source = load(sprintf('%s/GA-S%d_parcel_%s.mat', sjdat.roidir, ...
        1, freqs(f).name));
    source = source.source;
    source2 = load(sprintf('%s/GA-S%d_parcel_%s.mat', sjdat.roidir, ...
        2, freqs(f).name));
    assert(isequal(source2.source.label, source.label));
    source.pow = cat(2, source.pow, source2.source.pow);
    source.trialinfo = cat(1, source.trialinfo, source2.source.trialinfo);
    
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
    
    for l = 1:length(source.label),
        source.label{l} = regexprep(regexprep(source.label{l}, '-', ''), '/', '');
    end
    
    % pull out a few interesting measures
    if ~isfield(sourcescalars, 'trialinfo'),
        sourcescalars.trialinfo = source.trialinfo;
    else
        assert(isequaln(sourcescalars.trialinfo, source.trialinfo), 'trialinfo should match between freqbands!');
    end
    
    % TAKE EXACT THE SAME TIMEBINS AS IN THE OTHER SCRIPT
    timewins(1).name         = 'preref';
    timewins(1).samples      = 1:8; % pre-reference fixation to 50ms after reference onset
    timewins(end+1).name     = 'prestim';
    timewins(end).samples    = 29:36; % pre-stimulus fixation to 50ms after stimulus onset
    timewins(end+1).name     = 'ref';
    timewins(end).samples    = 7:22; % 0-750 ms after reference onset
    timewins(end+1).name     = 'stim';
    timewins(end).samples    = 35:51; % 0-750 ms after stimulus onset
    %timewins(end+1).name    = 'full_trial';
    %timewins(end).samples   = 1:55; % reference to end of stimulus
    
    for tw = 1:length(timewins),
        % pull out the power values
        this_time = timewins(tw).samples; % pre-reference fixation to 50ms after reference onset
        this_pow = squeeze(nanmean(source.pow(:, :, this_time), 3));
        for i = 1:length(source.label),
            sourcescalars.(freqs(f).name).(timewins(tw).name).(source.label{i}) = this_pow(i, :)';
        end
        if ~istable(sourcescalars.(freqs(f).name).(timewins(tw).name)),
            sourcescalars.(freqs(f).name).(timewins(tw).name) = struct2table(sourcescalars.(freqs(f).name).(timewins(tw).name));
        end
    end
    
    % =========================================== %
    % map table idx to MEG idx
    % change: keep all trials and fill with nans
    % =========================================== %
    
    %     [~, ~, tidx]    = intersect(sourcescalars.trialinfo(:, 18), tab.idx, 'stable');
    %     assert(size(sourcescalars.trialinfo, 1) == length(tidx));
    %     tab             = tab(tidx, :); % keep only that part of the table
    %     assert(isequal(tab.idx, sourcescalars.trialinfo(:, 18)), 'idx do not match');
    
    for r = 1:length(userois),
        for tw = 1:length(timewins),
            
            neuraldat = sourcescalars.(freqs(f).name).(timewins(tw).name).(regexprep(regexprep(userois{r}, '-', ''), '/', ''));
            varname = sprintf('%s_%s_%swin', freqs(f).name, regexprep(roinames{r}, '/', ''), ...
                regexprep(timewins(tw).name, '_', ''));
            
            % where to put these?
            [~, ~, tidx]    = intersect(sourcescalars.trialinfo(:, 18), tab.idx, 'stable');
            % should be: 3 4 6 7 8 9
            
            % insert and leave the rest nan
            tab.(varname) = nan(size(tab.idx));
            tab{tidx, varname} = neuraldat;
        end
    end
    
    % ================================ %%
    % SAVE MEG VALUES FOR HDDM!
    % ================================ %%
    
    writetable(tab, sprintf('%s/allsubjects_megall_4hddm_%s.csv', sjdat.csvdir, freqs(f).name));
    fprintf('%s/allsubjects_megall_4hddm_%s.csv \n', sjdat.csvdir, freqs(f).name);
    
end

%% ================================ %%
% CONCATENATE ACROSS DIFFERENT FREQS
% ================================ %%

for f = 1:3,
    tmptab = readtable(sprintf('%s/allsubjects_megall_4hddm_%s.csv', sjdat.csvdir, freqs(f).name));
    if f == 1,
        tabs = tmptab;
    else
        assert(isequal(tabs.idx, tmptab.idx));
        varnames = tmptab.Properties.VariableNames(contains(tmptab.Properties.VariableNames, freqs(f).name));
        varnames{end+1} = 'idx';
        tabs = join(tabs, tmptab(:, varnames));
%         tabs = join(tabs, tmptab, 'keys', ...
%             tmptab.Properties.VariableNames(~contains(tmptab.Properties.VariableNames, freqs(f).name)));
    end
end

% FINAL CSV FOR HDDM FITTING
writetable(tabs, sprintf('%s/allsubjects_megall_4hddm.csv', sjdat.csvdir));
writetable(tabs, sprintf('%s/HDDM/allsubjects_megall_4hddm.csv', sjdat.path));
fprintf('%s/allsubjects_meg_4hddm.csv \n', sjdat.csvdir);

%% ================================ %%
% remove outliers and normalize
% ================================ %%

%{
ported to matlab from
https://github.com/anne-urai/MEG/blob/master/hddm_fit.py#L98
https://github.com/anne-urai/MEG/blob/master/hddm_funcs.py#L26
%}
sjdat = subjectspecifics('ga');
tabs = readtable(sprintf('%s/allsubjects_megall_4hddm.csv', sjdat.csvdir));

% recode for binary outcomes
tabs.response(tabs.response == -1) = 0;
%tabs.group(tabs.group == 0) = -1; % repeaters (1) vs alternators (-1)

% make sure all non-neural vars are at the start for easier reading
non_neural_vars = {'idx', 'keep_meg', 'subj_idx', 'session', 'block', 'trial', ...
    'stimulus', 'hand', 'response', 'rt', 'correct', 'prev_hand', 'prev_resp', 'prev_stim', 'prev_correct', 'start_hand', ...
    'repeat', 'repetition', 'group', 'prevresp_correct', 'prevresp_error'};
neural_vars = setdiff(tabs.Properties.VariableNames, non_neural_vars);
tabs = tabs(:, cat(2, non_neural_vars, neural_vars));

% remove outliers > 500
value_threshold = 500;
for v = neural_vars,
    tabs{tabs{:, v} > value_threshold, v} = nan;
end

% normalize by z-scoring per person
for v = neural_vars,
    sjs = unique(tabs.subj_idx);
    for sj = 1:length(sjs),
        tabs{tabs.subj_idx == sjs(sj), v} = ...
            nanzscore(tabs{tabs.subj_idx == sjs(sj), v});
    end
end

% ================================ %%
% create a residual alpha signal 
% remove the global alpha
% ================================ %%

all_alpha = tabs.Properties.VariableNames(startsWith(tabs.Properties.VariableNames, 'alpha_') ...
    & endsWith(tabs.Properties.VariableNames, '_stimwin') ...
    & ~contains(tabs.Properties.VariableNames, '_lat_') ...
    & ~contains(tabs.Properties.VariableNames, {'m1', 'aips', 'pmdv', 'pces', 'ips01'}))';
assert(length(all_alpha) == 5);

all_alpha = tabs.Properties.VariableNames(startsWith(tabs.Properties.VariableNames, 'alpha_') ...
    & endsWith(tabs.Properties.VariableNames, '_stimwin') ...
    & ~contains(tabs.Properties.VariableNames, '_lat_'))';
tabs.alpha_global = mean(tabs{:, all_alpha}, 2);

% project out
tabs.alpha_ips01_stimwin_resid = nan(size(tabs.alpha_ips01_stimwin));
for sj = unique(tabs.subj_idx)',  
    for sess = 1:2,
        tabs.alpha_ips01_stimwin_resid(tabs.subj_idx == sj & tabs.session == sess) =  ...
            projectout(tabs.alpha_ips01_stimwin(tabs.subj_idx == sj & tabs.session == sess), ...
            tabs.alpha_global(tabs.subj_idx == sj & tabs.session == sess));
    end
end

% show that the previous choice effect is still significant!
glme = fitglme(tabs, 'alpha_ips01_stimwin_resid ~ 1 + stimulus + prev_resp + (1 | subj_idx)')

% ================================ %%
% create a residual gamma signal
% remove stimulus fluctuations
% ================================ %%

% project out
tabs.gamma_ips23_stimwin_resid = nan(size(tabs.gamma_ips23_stimwin));
for sj = unique(tabs.subj_idx)',  
    tabs.gamma_ips23_stimwin_resid(tabs.subj_idx == sj) =  ...
        projectout(tabs.gamma_ips23_stimwin(tabs.subj_idx == sj), ...
        tabs.stimulus(tabs.subj_idx == sj));
end

% ================================ %%
% average a few motor regions
%{
So, the simplest, principled suggestion would be to use the average of IPS/PostCeS, 
PMd, and M1 for all subsequent analyses on grounds of those showing both pre- and post-decisional 
beta effects. This is what I suggested throughout the ms. A conceivable alternative would be to 
split this up by parietal cortex (IPS/PostCeS) and frontal cortex (M1 and PMd), focus on 
the frontal results and present the IPS/PostCeS results in Supplement.
%} 
% ================================ %%


avg_rois = {'beta_m1_lat_prestimwin', 'beta_pmdv_lat_prestimwin', 'beta_pces_lat_prestimwin'};
tabs.beta_3motor_lat_prestimwin = mean(tabs{:, avg_rois}, 2);
   
avg_rois = {'beta_m1_lat_refwin', 'beta_pmdv_lat_refwin', 'beta_pces_lat_refwin'};
tabs.beta_3motor_lat_refwin = mean(tabs{:, avg_rois}, 2);
    
avg_rois = {'beta_m1_lat_stimwin', 'beta_pmdv_lat_stimwin', 'beta_pces_lat_stimwin'};
tabs.beta_3motor_lat_stimwin = mean(tabs{:, avg_rois}, 2);
    
avg_rois = {'beta_m1_lat_prestimwin', 'beta_pmdv_lat_prestimwin'};
tabs.beta_2motor_lat_prestimwin = mean(tabs{:, avg_rois}, 2);
   
avg_rois = {'beta_m1_lat_refwin', 'beta_pmdv_lat_refwin'};
tabs.beta_2motor_lat_refwin = mean(tabs{:, avg_rois}, 2);

% writetable(tabs, sprintf('%s/allsubjects_megall_4hddm_norm.csv', sjdat.csvdir));
% writetable(tabs, sprintf('%s/HDDM/allsubjects_megall_4hddm_norm.csv', sjdat.path));
% fprintf('%s/allsubjects_megall_4hddm_norm.csv \n', sjdat.csvdir);

% ================================ %%
% another version of the same files, with motor lateralization signals
% flipped
% ================================ %%

% when using lateralization, flip around to counteract stimulus-response mapping counterbalance
% change the 0 (= 'B') group around, so all point in L = -1, R = +1
% see email to Tobi, 29 July 2021
tabs.handgroup = mod(tabs.subj_idx, 2);
cols2flip = tabs.Properties.VariableNames(contains(tabs.Properties.VariableNames, '_lat_'))';
for c = 1:length(cols2flip),
    tabs{(tabs.handgroup == 1), cols2flip{c}} = -1 * tabs{(tabs.handgroup == 1), cols2flip{c}};
end

writetable(tabs, sprintf('%s/allsubjects_meg_complete.csv', sjdat.csvdir));
writetable(tabs, sprintf('%s/HDDM/allsubjects_meg_complete.csv', sjdat.path));
fprintf('%s/allsubjects_meg_complete.csv \n', sjdat.csvdir);

% ================================ %%
% select only what we need for the HDDMnn (smaller file)
% ================================ %%

tabs.Properties.VariableNames{'prev_resp'} = 'prevresp';
tabs.Properties.VariableNames{'prev_stim'} = 'prevstim';

tabs2 = tabs(:,{'subj_idx', ...
  'session', ...
  'block', ...
  'trial', ... 
  'stimulus', ...
  'hand', ...
  'response', ...
  'rt', ...
  'correct', ...
  'prevresp', ...
  'prevstim', ...
  'prev_correct', ...
  'repeat', ...
  'repetition', ...
  'group', ...
  'prevresp_correct', ...
  'prevresp_error', ...
  'alpha_ips01_stimwin_resid', ...
  'beta_3motor_lat_prestimwin', ...
  'beta_3motor_lat_refwin', ...
  'beta_3motor_lat_stimwin', ...
  'gamma_ips23_prestimwin', ...
  'gamma_ips23_prerefwin', ...
  'gamma_ips23_refwin', ...
  'gamma_ips23_stimwin'});

% remove rows with any nans, messes up HDDM
nans_idx = any(isnan(tabs2{:, :}), 2);
%assert(mean(nans_idx) < 0.1, 'trying to remove too many nan trials');
tabs2(nans_idx, :) = [];

writetable(tabs2, sprintf('%s/HDDM/allsubjects_meg_lean.csv', sjdat.path));
writetable(tabs2, sprintf('%s/CSV/allsubjects_meg_lean.csv', sjdat.path));

end
