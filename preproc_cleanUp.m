function [] = preproc_cleanUp(subjects, sessions)
% 1. remove trials without a response
% 2. remove trials with excessive head motion (outliers + >6mm from
% beginning of the recording)m
% 3. detect squid jumps by the intercept of the log-log power spect, remove
% 4. remo[ve principal component of the 50hz crossspectrum
% 5. bandstop filter at line noise freqs
% 6. remove car trials based on threshold on 0.75e-11
% 7. remove trials with muscle burst
% 8. remove trials with blinks during the stimulus
% 9. remove trials with saccades during the stimulus

if ~isdeployed,
    addpath(genpath('~/code/MEG'));
    addpath(genpath('~/code/Tools'));
    addpath('~/Documents/fieldtrip');
    ft_defaults;
    warning off;
end

set(groot, 'defaultaxesfontsize', 6);

if ~exist('subjects', 'var'),
    rng('default');
    allsubjectdata = subjectspecifics('ga'); subjects = allsubjectdata.all ;
    % randomize the order to reduce bias
    shuffle = @(x) x(randperm(length(x)));
    subjects = shuffle(subjects);
end

% for running on stopos
if ischar(subjects), subjects = str2double(subjects); end
makePlots = true;

% ==================================================================
% LOAD IN SUBJECT SPECIFICS AND READ DATA
% ==================================================================

for sj = subjects,
    
    fprintf('\nStarting subject number %d out of %d \n\n', find(sj == subjects), length(subjects));
    subjectdata = subjectspecifics(sj);

    if ~exist('sessions', 'var'), sessions = 1:length(subjectdata.session); end
    sessions = 1:length(subjectdata.session);
    
    for session = sessions,
        
        for rec = subjectdata.session(session).recsorder,
            
            clear predefined_thresholds; close all;
            fprintf('Starting sj %d, session %d, recording %d \n', sj, session, rec);
            tic;
            
            % don't redo!
            if exist(sprintf('%s/P%02d-S%d_rec%d_cleandata.mat', ...
                    subjectdata.preprocdir, sj, session, rec), 'file'),
%                 load(sprintf('%s/P%02d-S%d_rec%d_cleandata.mat', ...
%                     subjectdata.preprocdir, sj, session, rec));
                disp('Cleaned up file already exists, done!');
                continue
            end

			load(sprintf('%s/P%02d-S%d_rec%d_data.mat', ...
			subjectdata.preprocdir, sj, session, rec));

			% ==================================================================
			% WRITE A BEHAVIORAL CSV FILE
			% ==================================================================

			origtrialinfo = data.trialinfo;
			trialinfo2csv(data.trialinfo, sj, session, sprintf('%s/P%02d-S%d_rec%d_meg_all.csv', ...
			subjectdata.csvdir, sj, session, rec));

            % has the automatic part already been computed?
            if ~exist(sprintf('%s/P%02d-S%d_rec%d_preproc_cleanup_tmp.mat', subjectdata.preprocdir, sj, session, rec), 'file'),

                fprintf('\n\nstarting sj %d, session %d, recording %d\n\n', sj, session, rec);
                if makePlots, clf; fig = figure; end
                cnt = 1;
                
                % ==================================================================
                % REMOVE TRIALS WITHOUT A RESPONSE
                % ==================================================================
                
                cfg                     = [];
                cfg.trials              = true(1,length(data.trial));
                for t = 1:length(data.trial),
                    % check if there are noresp or multresp trials
                    cols2check = [7 8];
                    if any(isnan(data.trialinfo(t,cols2check))),
                        cfg.trials(t) = false;
                    end
                end
                fprintf('removing %d noresp trials \n', length(find(cfg.trials == 0)));
                data 					= ft_selectdata(cfg, data);
                
                % remove a few trials upfront that are just weird
                % why???
                if sj == 12,
                    cfg.trials = 1:length(data.trial);
                    cfg.trials((data.trialinfo(:, 12) == 6 & ...
                        data.trialinfo(:, 13) == 6 & data.trialinfo(:, 14) == 2)) = [];
                    data            = ft_selectdata(cfg, data);
                elseif sj== 35,
                    cfg.trials = 1:length(data.trial);
                    cfg.trials((data.trialinfo(:, 12) == 9 & ...
                        data.trialinfo(:, 13) == 10 & data.trialinfo(:, 14) == 2)) = [];
                    cfg.trials((data.trialinfo(:, 12) == 52 & ...
                        data.trialinfo(:, 13) == 8 & data.trialinfo(:, 14) == 1)) = [];
                    data            = ft_selectdata(cfg, data);
                end

                % ==================================================================
                % REMOVE TRIALS WITH EXCESSIVE HEAD MOTION
                % see http://www.fieldtriptoolbox.org/example/how_to_incorporate_head_movements_in_meg_analysis
                % ==================================================================
        
                cc_rel = computeHeadRotation(data);
        
                % find outliers
                [~, idx] = deleteoutliers(cc_rel);
                [t,~]    = ind2sub(size(cc_rel),idx);
        
                % only take those where the deviation is more than 6 mm
                t = t(any(abs(cc_rel(t, :)) > 6, 2));
        
                % show those on the plot
               % plot the rotation of the head
                if makePlots,
                    subplot(4,4,cnt); cnt = cnt + 1;
                    plot(cc_rel); ylabel('HeadM');
                    axis tight; box off;
                    hold on;
                    for thist = 1:length(t),
                        plot([t(thist) t(thist)], [max(get(gca, 'ylim')) max(get(gca, 'ylim'))], 'k.');
                    end
                end
        
                % remove those trials
                cfg                     = [];
                cfg.trials              = true(1, length(data.trial));
                cfg.trials(unique(t))   = false; % remove these trials
                data                    = ft_selectdata(cfg, data);
                fprintf('removing %d excessive head motion trials \n', length(find(cfg.trials == 0)));
        
                if makePlots,
                    subplot(4,4,cnt); cnt = cnt + 1;
                    if isempty(t),
                        title('No motion'); axis off;
                    else
                        % show head motion without those removed
                        cc_rel = computeHeadRotation(data);
            
                        % plot the rotation of the head
                        plot(cc_rel); ylabel('Motion resid');
                        axis tight; box off;
                    end
                end

                % ==================================================================
                % separate non MEG chans, save to disk
                % ==================================================================
                
                cfg         = [];
                cfg.channel = {'all', '-meg'};
                nonMEGdata  = ft_selectdata(cfg, data);
                
                savefast(sprintf('%s/P%02d-S%d_rec%d_nonMEGdata.mat', ...
                    subjectdata.preprocdir, sj, session, rec), 'nonMEGdata');
                clear nonMEGdata;
                
                % continue only with MEG chans
                cfg         = [];
                cfg.channel = {'MEG'};
                data        = ft_selectdata(cfg, data);
                data        = rmfield(data, 'cfg');
                
                % ==================================================================
                % plot a quick power spectrum
                % ==================================================================
                
                % save those cfgs for later plotting
                cfgfreq             = [];
                cfgfreq.method      = 'mtmfft';
                cfgfreq.output      = 'pow';
                cfgfreq.taper       = 'hanning';
                cfgfreq.channel     = 'MEG';
                cfgfreq.foi         = 1:130;
                cfgfreq.keeptrials  = 'no';
                cfgfreq.pad         = 'nextpow2';
                cfgfreq.feedback    = 'none';
                
                if makePlots,
                    % plot those data and save for visual inspection
                    freq                = ft_freqanalysis(cfgfreq, data);
                    subplot(4,4,cnt); cnt = cnt + 1;
                    loglog(freq.freq, freq.powspctrm, 'linewidth', 0.1); hold on;
                    loglog(freq.freq, mean(freq.powspctrm), 'k', 'linewidth', 1);
                    axis tight; axis square; box off;
                    set(gca, 'xtick', [10 50 100], 'tickdir', 'out', 'xticklabel', []);
                end
                
                % ==================================================================
                % REMOVE TRIALS WITH JUMPS
                % ==================================================================
                
                cfg             = [];
                cfg.detrend     = 'no'; % do not detrend if i want to look at CPP
                cfg.demean      = 'yes'; % demeaning is OK per trial, since ERFs will be baselined anyway
                cfg.feedback    = 'none';
                data            = ft_preprocessing(cfg, data);
                
                % get the fourier spectrum per trial and sensor
                cfgfreq.keeptrials  = 'yes';
                cfgfreq.foi 		= 1:50; % dont include highfreq line noise peaks
                freq                = ft_freqanalysis(cfgfreq, data);
                cfgfreq.foi 		= 1:130; % reset for plotting
                
                % compute the intercept of the loglog fourier spectrum on each trial
                disp('searching for trials with squid jumps...');
                intercept       = nan(size(freq.powspctrm, 1), size(freq.powspctrm, 2));
                x = [ones(size(freq.freq))' log(freq.freq)'];
                
                for t = 1:size(freq.powspctrm, 1),
                    for c = 1:size(freq.powspctrm, 2),
                        b = x\log(squeeze(freq.powspctrm(t,c,:)));
                        intercept(t,c) = b(1);
                    end
                end
                
                % detect jumps as outliers
                [~, idx] = deleteoutliers(intercept(:));
                if isempty(idx),
                    fprintf('no squid jump trials found \n');
                    cnt = cnt + 1;
                else
                    fprintf('removing %d squid jump trials \n', length(unique(t)));
                    [t,~] = ind2sub(size(intercept),idx);
                    
                    % remove those trials
                    cfg                 = [];
                    cfg.trials          = true(1, length(data.trial));
                    cfg.trials(unique(t)) = false; % remove these trials
                    data                = ft_selectdata(cfg, data);
                    
                    % plot the spectrum again
                    cfgfreq.keeptrials = 'no';
                    
                    if makePlots,
                        subplot(4,4,cnt); cnt = cnt + 1;
                        freq            = ft_freqanalysis(cfgfreq, data);
                        loglog(freq.freq, freq.powspctrm, 'linewidth', 0.1); hold on;
                        loglog(freq.freq, mean(freq.powspctrm), 'k', 'linewidth', 1);
                        axis tight; axis square; box off;
                        set(gca, 'xtick', [10 50 100], 'tickdir', 'out', 'xticklabel', []);
                        title(sprintf('%d jumps removed', length(unique(t))));
                    end
                end

                % ==================================================================
                % REMOVE FIRST PRINCIPAL COMPONENT OF THE 50HZ CROSS SPECTRM
                % ==================================================================
                
                % get cleaned data and the PCA projection matrix
                [outp, projection, artefact] = pca_guido(cat(2, data.trial{:})', data.fsample);
                
                % save projection matrix, apply to leadfields later
                save(sprintf('%s/P%02d-S%d_rec%d_pcaProjection.mat', ...
                    subjectdata.preprocdir, sj, session, rec), 'projection');
                
                if makePlots,
                    % plot topography of the artefact, real part
                    tmpdat              = data;
                    cfg                 = [];
                    cfg.vartrllength    = 1;
                    cfg.avgovertime     = 1;
                    tmpdat              = ft_timelockanalysis(cfg, tmpdat);
                    tmpdat              = rmfield(tmpdat, {'var', 'dof', 'cfg'});
                    tmpdat.time         = 1; % ignore temporal dimension
                    tmpdat.avg          = artefact(:, 1); % real part of the first PC
                end
                
                cfgtopo             = [];
                cfgtopo.marker      = 'off';
                cfgtopo.layout      = 'CTF275.lay';
                cfgtopo.comment     = 'no';
                cfgtopo.shading     = 'flat';
                cfgtopo.style       = 'straight';
                
                if makePlots,
                    subplot(4,4,cnt); cnt = cnt + 1;
                    ft_topoplotER(cfgtopo, tmpdat);
                    title(gca, '1st PC real part');
                    
                    subplot(4,4,cnt); cnt = cnt + 1;
                    tmpdat.avg = artefact(:, 2); % real part of the first PC
                    ft_topoplotER(cfgtopo, tmpdat);
                    title(gca, '1st PC imag part');
                end
                
                % replace the fieldtrip data
                data.trial = mat2cell(outp', ...
                    size(data.trial{1}, 1), cellfun(@length, data.trial));
                
                % plot powspect
                if makePlots,
                    cfgfreq.keeptrials = 'no';
                    freq            = ft_freqanalysis(cfgfreq, data);
                    subplot(4,4,cnt); cnt = cnt + 1;
                    loglog(freq.freq, freq.powspctrm, 'linewidth', 0.5); hold on;
                    loglog(freq.freq, mean(freq.powspctrm), 'k', 'linewidth', 1);
                    axis tight; ylims = get(gca, 'ylim'); axis square; box off;
                    set(gca, 'xtick', [10 50 100], 'tickdir', 'out', 'xticklabel', []);
                    title('After PCA');
                end
                
                % ==================================================================
                % FILTER LINE NOISE - do not apply high pass filter!
                % ==================================================================
                
                cfg             = [];
                cfg.bsfilter    = 'yes';
                cfg.bsfreq      = [49 51; 99 101; 149 151];
                cfg.feedback    = 'none';
                data            = ft_preprocessing(cfg, data);
                
                % plot power spectrum
                if makePlots,
                    freq            = ft_freqanalysis(cfgfreq, data);
                    subplot(4,4,cnt); cnt = cnt + 1;
                    loglog(freq.freq, freq.powspctrm, 'linewidth', 0.5); hold on;
                    loglog(freq.freq, mean(freq.powspctrm), 'k', 'linewidth', 1);
                    axis tight; ylim(ylims); axis square; box off;
                    title('After bandstop');
                    set(gca, 'xtick', [10 50 100], 'tickdir', 'out', 'xticklabel', []);
                end

				% ==================================================================
				% REMOVE CARS BASED ON THRESHOLD
				% ==================================================================

				disp('Looking for CAR artifacts...');
				cfg 			= [];
				cfg.trials 		= true(1, length(data.trial));
				worstChanRange 	= nan(1, length(data.trial));
				for t = 1:length(data.trial),
					% compute the range as the maximum of the peak-to-peak values within each channel
					ptpval = max(data.trial{t}, [], 2) - min(data.trial{t}, [], 2);
					% determine range and index of 'worst' channel
					worstChanRange(t) = max(ptpval);
				end

				% default range for peak-to-peak
				artfctdef.range           = 0.75e-11;

				% decide whether to reject this trial
				cfg.trials = (worstChanRange < artfctdef.range);
				fprintf('Removing %d CAR trials \n', length(find(cfg.trials == 0)));
				data = ft_selectdata(cfg, data);

				% save this temporary file
                if makePlots,
                    savefast(sprintf('%s/P%02d-S%d_rec%d_preproc_cleanup_tmp.mat', subjectdata.preprocdir, sj, session, rec), ...
                        'data','cfgfreq', 'cfgtopo', 'cnt', 'ylims', 'fig', 'origtrialinfo');
                else
                    savefast(sprintf('%s/P%02d-S%d_rec%d_preproc_cleanup_tmp.mat', subjectdata.preprocdir, sj, session, rec), ...
                        'data', 'cfgfreq', 'origtrialinfo');
                end

            end
            
            % ================================================================d==
            % if we're compiled, continue with automated preproc;
            % otherwise load data and wait for human input
            % https://stackoverflow.com/questions/6754430/determine-if-matlab-has-a-display-available
            % ================================================================d==

            if exist(sprintf('%s/P%02d-S%d_rec%d_artefactcfg.mat', subjectdata.preprocdir, sj, session, rec), 'file'),
                % if thresholds are already defined, don't redo
                predefined_thresholds = load(sprintf('%s/P%02d-S%d_rec%d_artefactcfg.mat', subjectdata.preprocdir, sj, session, rec));

                if exist(sprintf('%s/P%02d-S%d_rec%d_preproc_cleanup_tmp.mat', ...
                        subjectdata.preprocdir, sj, session, rec), 'file'),
                    load(sprintf('%s/P%02d-S%d_rec%d_preproc_cleanup_tmp.mat', ...
                        subjectdata.preprocdir, sj, session, rec));
                else
                    error('%s/P%02d-S%d_rec%d_preproc_cleanup_tmp.mat does NOT exist! \n', ...
                        subjectdata.preprocdir, sj, session, rec);
                end
            elseif usejava('desktop')
                disp('Starting interactive artifact rejection...');
                if exist(sprintf('%s/P%02d-S%d_rec%d_preproc_cleanup_tmp.mat', ...
                        subjectdata.preprocdir, sj, session, rec), 'file'),
                    load(sprintf('%s/P%02d-S%d_rec%d_preproc_cleanup_tmp.mat', ...
                        subjectdata.preprocdir, sj, session, rec));
                    % origNumTrials = length(data.trial);
                else
                    warning('%s/P%02d-S%d_rec%d_preproc_cleanup_tmp.mat does NOT exist, skipping... \n', ...
                        subjectdata.preprocdir, sj, session, rec);
                    continue
                end
            % IF NOT, DO VISUAL INSPECTION AND DEFINE
            elseif usejava('jvm') && ~feature('ShowFigureWindows'),
                disp('No Matlab windows detected, skipping interactive artiface rejection');
                continue;
            else
                warning('Not sure if I can do interactive artifact rejection or not');
                continue;
            end
            
            % ================================================================d==
            % REMOVE TRIALS WITH MUSCLE BURSTS BEFORE RESPONSE
            % ==================================================================
            
            if exist('predefined_thresholds', 'var'),
                 cfg_muscle = predefined_thresholds.cfg_muscle;
            else
                cfg                              = [];
                cfg.continuous                   = 'no'; % data has been epoched
                
                % channel selection, cutoff and padding
                cfg.artfctdef.zvalue.channel     = {'MEG'}; % make sure there are no NaNs
                cfg.artfctdef.zvalue.trlpadding  = -0.1; 
                cfg.artfctdef.zvalue.fltpadding  = 0; % can't be larger than trlpadding for segmented data
                cfg.artfctdef.zvalue.artpadding  = 0.1;
		        cfg.artfctdef.zvalue.demean      = 'yes';

                % algorithmic parameters
                cfg.artfctdef.zvalue.bpfilter    = 'yes';
                cfg.artfctdef.zvalue.bpfreq      = [110 140];
                cfg.artfctdef.zvalue.bpfiltord   = 9;
                cfg.artfctdef.zvalue.bpfilttype  = 'but';
                cfg.artfctdef.zvalue.hilbert     = 'yes';
                cfg.artfctdef.zvalue.boxcar      = 0.2;
                
                % set cutoff manually
                cfg.artfctdef.zvalue.cutoff      = 20;
                cfg.artfctdef.zvalue.interactive = 'yes';
                cfg.feedback                     = 'yes';
                cfg_muscle                       = ft_artifact_zvalue(cfg, data);
            end

            cfg                                 = [];
            cfg.artfctdef.reject                = 'complete';
            cfg.artfctdef.muscle.artifact       = cfg_muscle.artfctdef.zvalue.artifact;
            
            % only remove muscle bursts anytime before the response
            crittoilim = [data.trialinfo(:,1) - data.trialinfo(:,1) ...
                data.trialinfo(:,9) - data.trialinfo(:,1)]  ./ data.fsample;
            cfg.artfctdef.crittoilim        = crittoilim;
            data                            = ft_rejectartifact(cfg, data);

            % ==================================================================
            % INSPECTION for weird outliers or whatever - only in MEG
            % ==================================================================
            
            if exist('predefined_thresholds', 'var'),
                rejectidx       = predefined_thresholds.rejectidx;
                cfg.trials      = 1:length(data.trial);
                cfg.trials(ismember(data.trialinfo(:, 18), rejectidx)) = [];
                data            = ft_selectdata(cfg, data);
            else
                prerejectidx = data.trialinfo(:, 18);
                neighbours = load('ctf275_neighb.mat');
                data = ft_rejectvisual(struct('channel', {'MEG'}, ...
                    'neighbours', neighbours, 'layout', 'CTF275.lay'), data);
                postrejectidx = data.trialinfo(:, 18);
                rejectidx = setdiff(prerejectidx, postrejectidx);
            end
            
            % ==================================================================
            % PUT NONMEG CHANS BACK
            % ==================================================================
            
            load(sprintf('%s/P%02d-S%d_rec%d_nonMEGdata.mat', ...
                subjectdata.preprocdir, sj, session, rec));
            
            % only keep those trials that are also still in the MEG dat
            cfg         = [];
            cfg.trials  = ismember(nonMEGdata.trialinfo(:, end), data.trialinfo(:, end));
            nonMEGdata  = ft_selectdata(cfg, nonMEGdata);
            
            % append to MEG data
            grad = data.grad;
            data = ft_appenddata([], data, nonMEGdata);
            
            % keep grad struct
            data.grad = grad;
            if ~isfield(data, 'fsample'), data.fsample     = nonMEGdata.fsample; end
            if ~isfield(data, 'trialinfo'), data.trialinfo = nonMEGdata.trialinfo; end
            
            % ==================================================================
            % REMOVE TRIALS WITH EYEBLINKS (only during beginning of trial)
            % ==================================================================
            
            % plot distribution of blinks throughout the trial, before and after rejection
            if makePlots,
                subplot(4,4,cnt); cnt = cnt + 1;
                evRelcfg                    = [];
                evRelcfg.channel            = 'EOGV';
                evRelcfg.baselineCorrect    = 2;
                evRelcfg.nofeedback         = 0;
                evRelcfg.plotalltrials      = 1;
                evRelcfg.noresp             = 0;
                plotEventRelated(evRelcfg, data);
                title('All blinks'); ylabel('EOGV');
            end
            
            if exist('predefined_thresholds', 'var'),
                cfg_eogv = predefined_thresholds.cfg_eogv;
            else
                cfg                              = [];
                cfg.continuous                   = 'no'; % data has been epoched
                
                % channel selection, cutoff and padding
                cfg.artfctdef.zvalue.channel     = {'EOGV'};
                
                % use settings from Thomas Meindertsma
                cfg.artfctdef.zvalue.trlpadding  = -0.1; % avoid filter edge artefacts by setting to negative
                cfg.artfctdef.zvalue.fltpadding  = 0;
                cfg.artfctdef.zvalue.artpadding  = 0.05; % go a bit to the sides of blinks
                cfg.artfctdef.zvalue.demean      = 'yes';
                
                % algorithmic parameters
                cfg.artfctdef.zvalue.bpfilter   = 'yes';
                cfg.artfctdef.zvalue.bpfilttype = 'but';
                cfg.artfctdef.zvalue.bpfreq     = [1 15];
                cfg.artfctdef.zvalue.bpfiltord  = 4;
                cfg.artfctdef.zvalue.hilbert    = 'yes';
                
                % set cutoff
                cfg.artfctdef.zvalue.cutoff      = 2; % to detect all blinks, be strict
                cfg.artfctdef.zvalue.interactive = 'yes';
                cfg.feedback                     = 'yes';
                cfg_eogv                         = ft_artifact_zvalue(cfg, data);
            end
            
            cfg                             = [];
            cfg.artfctdef.reject            = 'complete';
            cfg.artfctdef.eog.artifact      = cfg_eogv.artfctdef.zvalue.artifact;
            
%             crittoilim = [data.trialinfo(:,1) - data.trialinfo(:,1) ...
%                 data.trialinfo(:,9) - data.trialinfo(:,1)]  / data.fsample;
            % reject blinks when they occur before the end of the second
            % stimulus
            crittoilim = [data.trialinfo(:,1) - data.trialinfo(:,1) ...
                data.trialinfo(:,5) - data.trialinfo(:,1) + 0.75*data.fsample]  / data.fsample;
            cfg.artfctdef.crittoilim        = crittoilim;
            data                            = ft_rejectartifact(cfg, data);
            
            % if there's nothing left, skip this...
            if isempty(data.trial), continue; end

            if makePlots,
                % plot EOGV activity after rejection
                subplot(4,4,cnt); cnt = cnt + 1;
                plotEventRelated(evRelcfg, data);
                % title(sprintf('%d blinks', bookkeep.rejected(bkcnt-1))); ylabel('EOGV');
            end
            
            % ==================================================================
            % REMOVE TRIALS WITH SACCADES (only during beginning of trial)
            % ==================================================================
            
            if makePlots,
                % plot distribution of blinks throughout the trial,
                % before and after rejection
                subplot(4,4,cnt); cnt = cnt + 1;
                evRelcfg.channel            = 'EOGH';
                plotEventRelated(evRelcfg, data);
                title('All sacc'); ylabel('EOGH');
            end
            
            if exist('predefined_thresholds', 'var'),
                cfg_eogh = predefined_thresholds.cfg_eogh;
            else
                cfg                              = [];
                cfg.continuous                   = 'no'; % data has been epoched
                
                % channel selection, cutoff and padding
                cfg.artfctdef.zvalue.channel     = {'EOGH'};
                
                % 001, 006, 0012 and 0018 are the vertical and horizontal eog chans
                cfg.artfctdef.zvalue.trlpadding  = -0.1; % padding doesnt work for data thats already on disk
                cfg.artfctdef.zvalue.fltpadding  = 0.1; % 
                cfg.artfctdef.zvalue.artpadding  = 0; % go a bit to the sides of blinks
                
                % algorithmic parameters
                cfg.artfctdef.zvalue.bpfilter   = 'yes';
                cfg.artfctdef.zvalue.bpfilttype = 'but';
                cfg.artfctdef.zvalue.bpfreq     = [1 15];
                cfg.artfctdef.zvalue.bpfiltord  = 4;
                cfg.artfctdef.zvalue.hilbert    = 'yes';
                
                % set cutoff
                cfg.artfctdef.zvalue.cutoff      = 4;
                cfg.artfctdef.zvalue.interactive = 'yes';
                cfg.feedback                     = 'yes';
                cfg_eogh                         = ft_artifact_zvalue(cfg, data);
            end

            cfg                             = [];
            cfg.artfctdef.reject            = 'complete';
            cfg.artfctdef.eog.artifact      = cfg_eogh.artfctdef.zvalue.artifact;
            
            % reject blinks when they occur before response
%             crittoilim = [data.trialinfo(:,1) - data.trialinfo(:,1) ...
%                 data.trialinfo(:,9) - data.trialinfo(:,1)]  / data.fsample;
            % reject blinks when they occur before the end of the second stimulus
            crittoilim = [data.trialinfo(:,1) - data.trialinfo(:,1) ...
                data.trialinfo(:,5) - data.trialinfo(:,1) + 0.75*data.fsample]  / data.fsample;
            cfg.artfctdef.crittoilim        = crittoilim;
            data                            = ft_rejectartifact(cfg, data);
            
            if makePlots,
                % plot EOGV activity after rejection
                subplot(4,4,cnt); cnt = cnt + 1;
                plotEventRelated(evRelcfg, data);
                % title(sprintf('%d sacc', bookkeep.rejected(bkcnt-1))); ylabel('EOGH');
            end
            
            % ==================================================================
            % plot final power spectrum
            % ==================================================================
            
            if makePlots,
                freq            = ft_freqanalysis(cfgfreq, data);
                subplot(4,4,cnt); cnt = cnt + 1;
                loglog(freq.freq, freq.powspctrm, 'linewidth', 0.5); hold on;
                loglog(freq.freq, mean(freq.powspctrm), 'k', 'linewidth', 1);
                axis tight; axis square; box off; ylim([ylims(1) max(get(gca, 'ylim'))]);
                set(gca, 'xtick', [10 50 100], 'tickdir', 'out');
                
                title(sprintf('Final %d%% kept: %d trials', ...
                    round(length(data.trial)/size(origtrialinfo, 1) * 100), length(data.trial)));
                xlabel(sprintf('P%02d S%d rec%d', sj, session, rec));
                
                print(gcf, '-dpdf', sprintf('%s/P%02d-S%d_rec%d_cleanup.pdf', subjectdata.figsdir, sj, session, rec));
            end
            
            % ==================================================================
            % save outputs
            % ==================================================================
            
            fprintf('Original number of trials: %d, percentage kept: %f \n', size(origtrialinfo, 1), 100*length(data.trial)/size(origtrialinfo, 1));
            disp(['Saving ' subjectdata.preprocdir sprintf('/P%02d-S%d_rec%d_cleandata.mat ... \n', sj, session, rec)]);
                       
            % csv file only for clean data
            trialinfo2csv(data.trialinfo, sj, session, sprintf('%s/P%02d-S%d_rec%d_meg_clean.csv', ...
                subjectdata.csvdir, sj, session, rec));
            
            % save manual thresholds
            save(sprintf('%s/P%02d-S%d_rec%d_artefactcfg.mat', subjectdata.preprocdir, sj, session, rec), ...
                'cfg_eogh', 'cfg_eogv', 'cfg_muscle', 'rejectidx');

            % ==================================================================
            % save clean data file (large)
            % ==================================================================

            data = rmfield(data, 'cfg'); % make the clean file much smaller
            savefast(sprintf('%s/P%02d-S%d_rec%d_cleandata.mat', subjectdata.preprocdir, sj, session, rec), 'data');
            disp(['SAVED ' subjectdata.preprocdir sprintf('/P%02d-S%d_rec%d_cleandata.mat', sj, session, rec)]);
            
            % remove temporary stuff
            delete(sprintf('%s/P%02d-S%d_rec%d_nonMEGdata.mat', subjectdata.preprocdir, sj, session, rec));
            % delete(sprintf('%s/P%02d-S%d_rec%d_preproc_cleanup_tmp.mat', subjectdata.preprocdir, sj, session, rec));
            toc;
        end
    end
end

end % function


function cc_rel = computeHeadRotation(data)

% ==================================================================
% from www.fieldtriptoolbox.org/example/how_to_incorporate_head_movements_in_meg_analysis
% ==================================================================

% take only head position channels
cfg         = [];
cfg.channel = {'HLC0011','HLC0012','HLC0013', ...
    'HLC0021','HLC0022','HLC0023', ...
    'HLC0031','HLC0032','HLC0033'};
hpos        = ft_selectdata(cfg, data);

% calculate the mean coil position per trial
coil1 = nan(3, length(hpos.trial));
coil2 = nan(3, length(hpos.trial));
coil3 = nan(3, length(hpos.trial));

for t = 1:length(hpos.trial),
    coil1(:,t) = [mean(hpos.trial{1,t}(1,:)); mean(hpos.trial{1,t}(2,:)); mean(hpos.trial{1,t}(3,:))];
    coil2(:,t) = [mean(hpos.trial{1,t}(4,:)); mean(hpos.trial{1,t}(5,:)); mean(hpos.trial{1,t}(6,:))];
    coil3(:,t) = [mean(hpos.trial{1,t}(7,:)); mean(hpos.trial{1,t}(8,:)); mean(hpos.trial{1,t}(9,:))];
end

% calculate the headposition and orientation per trial (function at the
% bottom of this script)
cc     = circumcenter(coil1, coil2, coil3);

% compute relative to the first trial
cc_rel = [cc - repmat(cc(:,1),1,size(cc,2))]';
cc_rel = 1000*cc_rel(:, 1:3); % translation in mm

end
