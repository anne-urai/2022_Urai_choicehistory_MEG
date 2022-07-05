function dics_scalars_stats()

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
    'session', 'roi', 'var', 'timewin'}), 'rows');
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

for statm = 1:length(statsmethods),
    
    for tw = 1:length(timewins),
        
        contrasts       = [4 5 4 5 6 14 7 15 ];
        contrast_names  = [4 5 40 50 6 14 7 15];
        %contrasts = 15; contrast_names = 15;
        %  contrasts = 7; contrast_names = 7;
        
        for ci = 1:length(contrasts),
            c = contrasts(ci);
            contrast_code = contrast_names(ci);
            
            % V1, V2-V4, V3AB, MT+, IPS0/1, IPS2/3, IPS4/5 (visual field maps),
            % aIPS, IPS/postCeS, PMd/v, M1 (?motor planning areas?)
            switch contrast_code
                
                case {5, 7, 50} % lateralization
                    userois = {'wang_vfc_lat_lateralized_V1', 'wang_vfc_lat_lateralized_V2-V4', ...
                        'wang_vfc_lat_lateralized_MT/MST', 'wang_vfc_lat_lateralized_V3A/B',  'wang_vfc_lat_lateralized_IPS0/1', ...
                        'wang_vfc_lat_lateralized_IPS2/3',  'jwg_aIPS_lateralized', ...
                        'jwg_IPS_PCeS_lateralized', 'glasser_premotor_lateralized_PMd/v', 'jwg_M1_lateralized'} ;
                    
                otherwise
                    userois = {'wang_vfc_V1', 'wang_vfc_V2-V4', ...
                        'wang_vfc_MT/MST', 'wang_vfc_V3A/B',  'wang_vfc_IPS0/1', ...
                        'wang_vfc_IPS2/3', 'jwg_symm_aIPS', ...
                        'jwg_symm_IPSPCeS', 'glasser_premotor_symm_PMd/v', 'jwg_symm_M1'} ;
                    
            end
            % always use the same names
            roinames = {'V1', 'V2-4', 'MT+',  'V3A/B', 'IPS0/1', ...
                'IPS2/3', 'aIPS', 'IPS/PCeS   ', 'PMd/v' 'M1'};
            cmap = (viridis(length(roinames)+1));
            tic;
            
            for f = 3,
                
                % grab the datapoints for each person from the table
                tmp_tab = tab(tab.contrast==c, :);
                vars = unique(tmp_tab.var);
                vars = setdiff(vars, '(Intercept)');
                assert(length(vars) > 0, 'no variables found');
                % xjit = unifrnd(-0.09, 0.09, [60, 1]);
                
                for v = 1:length(vars),
                    
                    % plot this
                    close all;
                    subplot(441); hold on;
                    plot([0.5 length(userois)+0.5], [0 0], 'k:', 'linewidth', 0.5);
                    
                    for r = 1:length(userois),
                        
                        % pvalue from GLME
                        neural_data = tab(tab.contrast==c & ...
                            strcmp(tab.var, vars{v}) & ...
                            contains(tab.roi, userois{r}) &  ...
                            contains(tab.freq, freqs(f).name) & ...
                            tab.session == 0 & ...
                            tab.subj_idx == 0 & ...
                            contains(tab.timewin, timewins(tw)), :);
                        % pval = neural_data.pval * 5; % use 0.1 instead of 0.05
                        % assert(size(neural_data, 1) == 1);
                        
                        if size(neural_data, 1) ~= 1,
                            continue;
                        end
                        
                        neural_data.ci_high = neural_data.ci_high - neural_data.value;
                        neural_data.ci_low = neural_data.value - neural_data.ci_low;
                        
%                         % FDR correction
%                         % across 1 contrast: all freqs, ROIs, time windows
%                         neural_data_fdr = tab(tab.contrast==c & ...
%                             tab.session == 0 & ...
%                             tab.subj_idx == 0, :);
%                         [h, crit_p, adj_ci_cvrg, adj_p] = fdr_bh(neural_data_fdr.pval, 0.05, 'pdep');
                        
                        % layout depends on significance
                        if neural_data.adj_p < 0.05,
                            if neural_data.value > 0,
                                mysigstar(gca, r, neural_data.value+neural_data.ci_high*1.2, ...
                                    neural_data.adj_p, cmap(r, :));
                            else
                                mysigstar(gca, r, neural_data.value-neural_data.ci_low*1.4, ...
                                    neural_data.adj_p, cmap(r, :));
                            end
                            mec = [1 1 1]; % filled marker
                            mfc = cmap(r, :);
                            mz = 7;
                        else % unfilled marker for nonsignificant
                            mec = cmap(r, :);
                            mfc = [1 1 1];
                            mz = 4;
                        end
                        
                        % plot mean +- sem
                        errorbar(r, neural_data.value, neural_data.ci_low, neural_data.ci_high, ...
                            'marker', 's', 'capsize', 0, 'color', cmap(r, :), 'markerfacecolor', mfc, ...
                            'markersize', mz, 'markeredgecolor', mec);
                    end
                    
                    % layout
                    axisNotSoTight; xlim([0.5 r+0.5]);
                    % ylim([-2.9 2.9]);
                    offsetAxes;
                    set(gca, 'xtick', 1:length(userois), 'xticklabel', roinames, ...
                        'xticklabelrotation', -45, 'ticklabelinterpreter', 'tex');
                    
                    % color these so they match the atlas plot
                    % https://undocumentedmatlab.com/articles/customizing-axes-tick-labels
                    ax = gca;
                    for i = 1:length(userois),
                        ax.XTickLabel{i} = sprintf('\\color[rgb]{%f,%f,%f}%s', cmap(i,:), ax.XTickLabel{i});
                    end
                    
                    
                    
                    ylabel('Effect size (\Delta%)');
                    ylabel('');
                    
                    switch timewins{tw}
                        case 'stimulus'
                            tw_name = 'Test stimulus';
                        case 'pre_stim_time'
                            tw_name = 'Pre-stimulus baseline';
                        case 'pre_ref_time'
                            tw_name = 'Pre-reference baseline';
                        case 'full_trial'
                            tw_name = 'Full trial';
                        case 'reference'
                            tw_name = 'Reference';
                    end
                    
                    switch vars{v}
                        case 'stimulus'
                            var_name = 'stimulus category';
                            switch freqs(f).name
                                case 'gamma'
                                    ylim([-0.5 1.7]);
                            end
                        case 'prev_correct'
                            var_name = 'previous feedback';
                            %ylim([-0.5 1.7]);
                        case 'prev_resp:prev_correct'
                            var_name = 'previous choice*feedback';
                        case {'prev_resp', 'prevresp_correct'}
                            switch freqs(f).name
                                case 'alpha'
                                    ylim([-1 2.5]);
                                case 'gamma'
                                    ylim([-0.6 1.3]);
                                    ylim([-0.6 1.95]);

                            end
                            switch vars{v}
                                case 'prev_resp'
                                    var_name = 'previous choice';
                                case 'prevresp_correct'
                                    var_name = 'previous correct choice';
                            end
                        case 'prevresp_error'
                            var_name = 'previous error choice';
                            
                            switch freqs(f).name
                                case 'alpha'
                                    ylim([-2 3.5]);
                                case 'gamma'
                                    ylim([-1 2]);
                            end
                        case 'prevhand_error'
                            var_name = 'previous error action';
                            ylim([-1.5, 2.9]);
                        case 'prevhand_correct'
                            var_name = 'previous correct action';
                            ylim([-1.5, 2.9]);
                            
                        case 'prev_wrong',
                            var_name = 'previous negative feedback';
                        case 'hand';
                            var_name = 'action preparation';
                            
                            switch freqs(f).name
                                case 'alpha'
                                    %  ylim([-2 2]);
                                case 'gamma'
                                    ylim([-1, 1]);
                                case 'beta'
                                    ylim([-2.2, 0.5]);
                            end
                        case 'prev_hand'
                            var_name = 'previous action';
                            switch freqs(f).name
                                case 'alpha'
                                    %  ylim([-2 2]);
                                case 'gamma'
                                    ylim([-1, 1.2]);
                                case 'beta'
                                    ylim([-1 2.2]);
                            end
                        otherwise
                            var_name = vars{v};
                    end
                    %
                    set(gca, 'fontsize', 6);
                    if strcmp(freqs(f).name, 'gamma') || c == 7,
                        title({sprintf('Effect of %s', var_name); ...
                            [tw_name ' interval']}, 'fontsize', 7, ...
                            'interpreter', 'none', 'fontweight', 'normal', 'fontangle', 'italic');
                        
                    end
                    
                    tightfig;
                    print(gcf, '-dpdf', sprintf('%s/dics_ebars_contrast%d_%s_%s_%s_%s.pdf', sjdat.figsdir, ...
                        contrast_code, timewins{tw},freqs(f).name, vars{v}, statsmethods{statm}));
                    toc;
                end
            end
            
        end
        
    end
end
close all;

end

