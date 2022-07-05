function dics_stats_print_summary
%{
1. interaction between current stimulus and previous response, for IPS0/1 and IPS2/3
2. Across-subjects correlation of the strength of history effects in IPS2/3-gamma and IPS0/1-alpha.
3. Across-subjects correlation of the strength of history effects in IPS2/3-gamma and sensory effect in IPS0/1-gamma
(might be negative, along the Akrami logic).
4. does the history effect in IPS0/1 alpha  (and confirm for IPS2/3 gamma) correlate with p(repeat)
    or individual DDM history parameters from the stimcoding model?
%}

%%

close all;
set(groot, 'DefaultFigureWindowStyle','normal', 'DefaultAxesFontSize', 8);
sjdat = subjectspecifics('ga');
freqs = dics_freqbands; % retrieve specifications
vs = 1:3;

% =========================================== %
% GET TABLES WITH INDIVIDUAL ESTIMATES
% =========================================== %

% MERGE WITH GLME EFFECT SIZES
for v = vs,
    %filename = sprintf('S%d_%s_%s', 0, freqs(v).name, 'glme');
    tabs{v} = readtable(sprintf('%s/effectsizes_%s.csv', sjdat.statsdir, freqs(v).name));
end
tab = vertcat(tabs{:});
% remove duplicates
[~, ind] = unique(tab(:, {'subj_idx', 'group', 'contrast', 'formula', 'freq', ...
    'session', 'roi', 'var', 'timewin'}), 'rows');
tab = tab(ind,:);

% FDR correction
[~, crit_p, ~, adj_p] = fdr_bh(tab.pval(~isnan(tab.pval)));
tab.adj_p = nan(size(tab.pval));
tab.adj_p(~isnan(tab.pval)) = adj_p; % use adjusted values
       

% =========================================== %
% 1. interaction between current stimulus and previous response, for IPS0/1 and IPS2/3
% =========================================== %

interaction_model = tab(tab.contrast == 12 ...
    & contains(tab.group, 'all') ...
    & contains(tab.freq, 'gamma') ...
    & contains(tab.timewin, 'stimulus') ...
    & contains(tab.roi, 'wang_vfc_IPS2/3') ...
    & tab.subj_idx == 0, :);

% (main effect of stimulus = 0.358, CI [-0.0098, 0.7270], p = 0.0564;
% main effect of previous choice = 0.68141, CI [0.31298, 1.0499], p = 0.0003;
% interaction -0.1885, CI [-0.5569, 0.1798], p = 0.3158).

fprintf(['\nIPS2/3 gamma: main effect of stimulus = %.4f, CI [%.4f, %.4f, p = %.4f; ' ...
    'main effect of previous choice = %.4f, CI [%.4f, %.4f], p = %.4f; '...
    'interaction = %.4f, CI [%.4f, %.4f], p = %.4f\n'], ...
    interaction_model{strcmp(interaction_model.var, 'stimulus'), 'value'}, ...
    interaction_model{strcmp(interaction_model.var, 'stimulus'), 'ci_low'}, ...
    interaction_model{strcmp(interaction_model.var, 'stimulus'), 'ci_high'}, ...
    interaction_model{strcmp(interaction_model.var, 'stimulus'), 'adj_p'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp'), 'value'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp'), 'ci_low'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp'), 'ci_high'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp'), 'pval'}, ...
    interaction_model{strcmp(interaction_model.var, 'stimulus:prev_resp'), 'value'}, ...
    interaction_model{strcmp(interaction_model.var, 'stimulus:prev_resp'), 'ci_low'}, ...
    interaction_model{strcmp(interaction_model.var, 'stimulus:prev_resp'), 'ci_high'}, ...
    interaction_model{strcmp(interaction_model.var, 'stimulus:prev_resp'), 'adj_p'});

interaction_model = tab(tab.contrast == 12 ...
    & contains(tab.group, 'all') ...
    & contains(tab.freq, 'alpha') ...
    & contains(tab.timewin, 'stimulus') ...
    & contains(tab.roi, 'wang_vfc_IPS0/1') ...
    & tab.subj_idx == 0, :);

fprintf(['\nIPS0/1 alpha: main effect of stimulus = %.4f, CI [%.4f, %.4f, p = %.4f; ' ...
    'main effect of previous choice = %.4f, CI [%.4f, %.4f], p = %.4f; '...
    'interaction = %.4f, CI [%.4f, %.4f], p = %.4f\n'], ...
    interaction_model{strcmp(interaction_model.var, 'stimulus'), 'value'}, ...
    interaction_model{strcmp(interaction_model.var, 'stimulus'), 'ci_low'}, ...
    interaction_model{strcmp(interaction_model.var, 'stimulus'), 'ci_high'}, ...
    interaction_model{strcmp(interaction_model.var, 'stimulus'), 'pval'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp'), 'value'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp'), 'ci_low'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp'), 'ci_high'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp'), 'adj_p'}, ...
    interaction_model{strcmp(interaction_model.var, 'stimulus:prev_resp'), 'value'}, ...
    interaction_model{strcmp(interaction_model.var, 'stimulus:prev_resp'), 'ci_low'}, ...
    interaction_model{strcmp(interaction_model.var, 'stimulus:prev_resp'), 'ci_high'}, ...
    interaction_model{strcmp(interaction_model.var, 'stimulus:prev_resp'), 'adj_p'});

% =========================================== %
% 2. Across-subjects correlation of the strength of history effects in IPS2/3-gamma and IPS0/1-alpha.
% 3. Across-subjects correlation of the strength of history effects in IPS2/3-gamma and sensory effect in IPS0/1-gamma
% (might be negative, along the Akrami logic).
% =========================================== %

ips23_choicehist = tab(tab.contrast == 4 ...
    & contains(tab.group, 'all') ...
    & contains(tab.var, 'prev_resp') ...
    & contains(tab.freq, 'gamma') ...
    & contains(tab.timewin, 'stimulus') ...
    & contains(tab.roi, 'wang_vfc_IPS2/3') ...
    & tab.subj_idx > 0, :);

ips01_choicehist = tab(tab.contrast == 4 ...
    & contains(tab.group, 'all') ...
    & contains(tab.var, 'prev_resp') ...
    & contains(tab.freq, 'alpha') ...
    & contains(tab.timewin, 'stimulus') ...
    & contains(tab.roi, 'wang_vfc_IPS0/1') ...
    & tab.subj_idx > 0, :);

ips01_sensory = tab(tab.contrast == 4 ...
    & contains(tab.group, 'all') ...
    & contains(tab.var, 'stimulus') ...
    & contains(tab.freq, 'gamma') ...
    & contains(tab.timewin, 'stimulus') ...
    & contains(tab.roi, 'wang_vfc_IPS0/1') ...
    & tab.subj_idx > 0, :);

[rho, pval] = corr(ips23_choicehist.value, ips01_choicehist.value);
bf = corrbf(rho, height(ips23_choicehist));
fprintf('IPS2/3 gamma choicehist vs. IPS0/1 alpha choicehist: r = %.3f, p = %.4f, Bf10 = %.4f \n', rho, pval, bf);

% [rho, pval] = corr(ips23_choicehist.value, pmdv_motorhist.value);
% bf = corrbf(rho, height(ips23_choicehist));
% fprintf('IPS2/3 gamma choicehist vs. pooled motorhist: r = %.3f, p = %.4f, Bf10 = %.4f \n', rho, pval, bf);

[rho, pval] = corr(ips23_choicehist.value, ips01_sensory.value);
fprintf('IPS2/3 gamma choicehist vs. IPS0/1 gamma sensory: r = %.3f, p = %.4f \n', rho, pval);
[rho, pval] = corr(ips01_choicehist.value, ips01_sensory.value);
fprintf('IPS0/1 alpha choicehist vs. IPS0/1 gamma sensory: r = %.3f, p = %.4f \n', rho, pval);


% =========================================== %
% 2. Across-subjects correlation of the strength of history effects in
% IPS2/3-gamma and motor beta-lateralization
% =========================================== %

ips23_choicehist = tab(tab.contrast == 4 ...
    & contains(tab.group, 'all') ...
    & contains(tab.var, 'prev_resp') ...
    & contains(tab.freq, 'gamma') ...
    & contains(tab.timewin, 'stimulus') ...
    & contains(tab.roi, 'wang_vfc_IPS2/3') ...
    & tab.subj_idx > 0, :);

pmdv_motorhist = tab(tab.contrast == 5 ...
    & contains(tab.group, 'all') ...
    & contains(tab.var, 'prev_hand') ...
    & contains(tab.freq, 'beta') ...
    & contains(tab.timewin, 'reference') ...
    & contains(tab.roi, 'pooled_motor_lateralized') ...
    & tab.subj_idx > 0, :);

[rho, pval] = corr(ips23_choicehist.value, pmdv_motorhist.value);
bf = corrbf(rho, height(ips23_choicehist));
fprintf('IPS2/3 gamma choicehist vs. pooled motorhist: r = %.3f, p = %.4f, Bf10 = %.4f \n', rho, pval, bf);

%%  =========================================== %
%% figure 2 - supp 3
% does the prevchoice signal interact with prevfeedback?
% =========================================== %

fprintf('\n previous feedback interaction: \n')

interaction_model = tab(tab.contrast == 14 ...
    & contains(tab.group, 'all') ...
    & contains(tab.freq, 'gamma') ...
    & contains(tab.timewin, 'stimulus') ...
    & contains(tab.roi, 'wang_vfc_IPS2/3') ...
    & tab.subj_idx == 0, :);

fprintf(['\nIPS2/3 gamma: main effect of previous choice = %.4f, CI [%.4f, %.4f, p = %.4f;\n' ...
    'main effect of previous feedback = %.4f, CI [%.4f, %.4f], p = %.4f;\n'...
    'interaction = %.4f, CI [%.4f, %.4f], p = %.4f\n'], ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp'), 'value'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp'), 'ci_low'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp'), 'ci_high'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp'), 'adj_p'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_error'), 'value'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_error'), 'ci_low'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_error'), 'ci_high'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_error'), 'pval'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp:prev_error'), 'value'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp:prev_error'), 'ci_low'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp:prev_error'), 'ci_high'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp:prev_error'), 'adj_p'});

interaction_model = tab(tab.contrast == 14 ...
    & contains(tab.group, 'all') ...
    & contains(tab.freq, 'alpha') ...
    & contains(tab.timewin, 'stimulus') ...
    & contains(tab.roi, 'wang_vfc_IPS0/1') ...
    & tab.subj_idx == 0, :);

fprintf(['\nIPS0/1 alpha: main effect of previous choice = %.4f, CI [%.4f, %.4f], p = %.4f;\n' ...
    'main effect of previous feedback = %.4f, CI [%.4f, %.4f], p = %.4f;\n'...
    'interaction = %.4f, CI [%.4f, %.4f], p = %.4f\n'], ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp'), 'value'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp'), 'ci_low'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp'), 'ci_high'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp'), 'adj_p'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_error'), 'value'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_error'), 'ci_low'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_error'), 'ci_high'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_error'), 'adj_p'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp:prev_error'), 'value'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp:prev_error'), 'ci_low'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp:prev_error'), 'ci_high'}, ...
    interaction_model{strcmp(interaction_model.var, 'prev_resp:prev_error'), 'pval'});


%%  =========================================== %
% does the history effect in IPS0/1 alpha  (and confirm for IPS2/3 gamma)
% correlate with p(repeat) or individual DDM history parameters from the stimcoding model?
% =========================================== %

% 1. get all trial data
tab = readtable(sprintf('%s/HDDM/allsubjects_meg_4hddm_norm.csv', sjdat.path));
[g, perf] = findgroups(tab(:, {'subj_idx'}));

% DO I USE THE REPETITION AVERAGE ACROSS ALL TRIALS?
[perf.repeat]  = splitapply(@nanmean, tab.repeat, g);
[perf.repeat2] = splitapply(@unique, tab.repetition, g);

% dprime and crit only computed on MEG trials
[perf.dprime, perf.crit] = splitapply(@dprime, tab.stimulus, tab.response, g);

% 2. get HDDM estimates
hddm_models = {'m_prevchoice_dcz', 'gamma_ips23_stimwin'};

for m = 1:length(hddm_models),
    
    % read in the filename
    model_filename = sprintf('%s/MEG_HDDM_all_clean/%s/results_combined.csv', ...
        sjdat.path, hddm_models{m});
    if ~exist(model_filename', 'file'),
        fprintf('%s does not exist \n', model_filename);
        continue
    end
    
    hddm_results_tmp = readtable(model_filename);
    hddm_results_tmp.subj_idx = nan(size(hddm_results_tmp.Var1));
    
    % parse the column with varnames
    for v = 1:height(hddm_results_tmp),
        varnames = split(hddm_results_tmp.Var1(v), ["_subj."]);
        hddm_results_tmp.varname{v} = [hddm_models{m} '_' varnames{1}];
        
        if length(varnames) > 1,
            hddm_results_tmp.subj_idx(v) = str2num(varnames{2});
        end
    end
    
    hddm_results_tmp(contains(hddm_results_tmp.varname, 'std'), :) = [];
    hddm_models_tmp = unstack(hddm_results_tmp(:, {'mean', 'subj_idx', 'varname'}), 'mean', 'varname');
    
    % put together
    if m == 1,
        hddm_results = hddm_models_tmp;
    else
        hddm_results = join(hddm_results, hddm_models_tmp, 'keys', {'subj_idx'});
    end
end

% join together
tab2 = join(hddm_results, perf, 'keys', {'subj_idx'});

% =========================================== %
%% correlate HDDM with GLME estimates
% =========================================== %

assert(isequal(ips23_choicehist.subj_idx, tab2.subj_idx), 'subj_idx must match to correlate');

[rho, pval] = corr(ips23_choicehist.value, tab2.repeat);
fprintf('IPS2/3 gamma choicehist vs. repetition: r = %.3f, p = %.4f \n', rho, pval);

[rho, pval] = corr(ips23_choicehist.value, tab2.prevchoice_dcz_v_prevresp);
fprintf('IPS2/3 gamma choicehist vs. history shift in drift bias: r = %.3f, p = %.4f \n', rho, pval);

[rho, pval] = corr(ips23_choicehist.value, tab2.prevchoice_dcz_z_prevresp);
fprintf('IPS2/3 gamma choicehist vs. history shift in starting point: r = %.3f, p = %.4f \n', rho, pval);

[rho, pval] = corr(tab2.value, tab2.prevchoice_dcz_z_prevresp);
fprintf('IPS2/3 gamma choicehist vs. history shift in starting point: r = %.3f, p = %.4f \n', rho, pval);

% correlate with GLME estimates - IPS0/1
assert(isequal(ips01_choicehist.subj_idx, tab2.subj_idx), 'subj_idx must match to correlate');

[rho, pval] = corr(ips01_choicehist.value, tab2.repeat);
fprintf('IPS0/1 alpha choicehist vs. repetition: r = %.3f, p = %.4f \n', rho, pval);

[rho, pval] = corr(ips01_choicehist.value, tab2.prevchoice_dcz_v_prevresp);
fprintf('IPS0/1 alpha choicehist vs. history shift in drift bias: r = %.3f, p = %.4f \n', rho, pval);

[rho, pval] = corr(ips01_choicehist.value, tab2.prevchoice_dcz_z_prevresp);
fprintf('IPS0/1 alpha choicehist vs. history shift in starting point: r = %.3f, p = %.4f \n', rho, pval);

%%  =========================================== %
% do the neural history effects correlate with
% Fruend regression weights?
% =========================================== %

for sj = sjdat.clean,
    tab_fruend = readtable(sprintf('%s/CSV/Fruend/sj_%02d_kernels.csv', sjdat.path, sj));
    
    % select what we want
    tab_fruend = tab_fruend(tab_fruend.Var1 == 0, :);
    tab_fruend.subj_idx = sj;
    
    if sj == min(sjdat.clean),
        fruend = tab_fruend;
    else
        fruend = [fruend; tab_fruend];
    end
end

[rho, pval] = corr(perf.repeat, fruend.resp_kernel);
fprintf('repetition vs. fruend respw: r = %.3f, p = %.4f \n', rho, pval);

[rho, pval] = corr(perf.repeat, fruend.stim_kernel);
fprintf('repetition vs. fruend stimw: r = %.3f, p = %.4f \n', rho, pval);

[rho1, pval1] = corr(ips23_choicehist.value, fruend.resp_kernel);
fprintf('IPS2/3 gamma vs. fruend respw: r = %.3f, p = %.4f \n', rho1, pval1);

[rho2, pval2] = corr(ips23_choicehist.value, fruend.resp_kernel, 'type', 'spearman');
fprintf('IPS2/3 gamma vs. fruend respw SPEARMAN: r = %.3f, p = %.4f \n', rho2, pval2);

close all;
subplot(221);
scatter(fruend.resp_kernel, ips23_choicehist.value, 30, perf.repeat, 'filled');
lsline;
axis square;
xlabel('Choice weight, lag 1');
ylabel({'IPS23 gamma';'effect of previous choice'});
title({sprintf('Pearson r = %.3f, p = %.2f', rho1, pval1), ...
    sprintf('Spearman rho = %.3f, p = %.2f', rho2, pval2), ''});
offsetAxes;
tightfig;
print(gcf, '-dpdf', sprintf('%s/ips23gamma_vs_fruend.pdf', sjdat.figsdir));

[rho, pval] = corr(ips01_choicehist.value, fruend.resp_kernel);
fprintf('IPS0/1 alpha vs. fruend respw: r = %.3f, p = %.4f \n', rho, pval);

[rho, pval] = corr(ips01_choicehist.value, fruend.resp_kernel, 'type', 'spearman');
fprintf('IPS0/1 alpha vs. fruend respw SPEARMAN: r = %.3f, p = %.4f \n', rho, pval);

% =========================================== %

[rho, pval] = corr(hddm_results.prevchoice_dcz_v_prevresp, fruend.resp_kernel);
fprintf('hddm v_prevresp vs. fruend respw : r = %.3f, p = %.4f \n', rho, pval);

[rho, pval] = corr(hddm_results.prevchoice_dcz_z_prevresp, fruend.resp_kernel);
fprintf('hddm z_prevresp vs. fruend respw : r = %.3f, p = %.4f \n', rho, pval);


% =========================================== %
%% correlate HDDM with GLME estimates
% other way around: does the neural effect on drift bias predict behavior?
% =========================================== %

[rho, pval] = corr(tab2.gamma_ips23_stimwin_v_gamma_ips23_stimwin, perf.repeat);
fprintf('gamma effect on drift bias vs. p(repeat): r = %.3f, p = %.4f \n', rho, pval);

[rho, pval] = corr(tab2.gamma_ips23_stimwin_v_gamma_ips23_stimwin, fruend.resp_kernel);
fprintf('gamma effect on drift bias vs. choice weight lag 1: r = %.3f, p = %.4f \n', rho, pval);

end