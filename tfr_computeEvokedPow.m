function [] = tfr_computeEvokedPow(sj, sessions, n)
% time-frequency using multitapers

if ~isdeployed,
    addpath(genpath('~/code/MEG'));
    addpath(genpath('~/code/Tools'));
    addpath('~/Documents/fieldtrip');
    ft_defaults;  % ft_defaults should work in deployed app?
end
warning off;

if ~exist('n', 'var'), n = [1:31]; end
if ~exist('sessions', 'var'), sessions = [1 2]; end

% for running on stopos
if ischar(sj), sj = str2double(sj);
end
if ischar(sessions), session = str2double(sessions);
end
if ischar(n), n = str2double(n);
end

tic;
subjectdata = subjectspecifics(sj);

% ==================================================================
% USE CONTRAST FILES FOR ERFs
% ==================================================================

locks = {'ref', 'stim', 'resp', 'fb'};

% Only small thing here: when normalizing the evoked TFRs, you should
% use the original baseline from the total power analysis that way you
% can compare the total power and evoked power quantitatively.
% email Tobi, 27.06.2017

for session = sessions,
    fprintf('running sj %d, session %d \n', sj, session);

    clearvars -except sj n subjectdata locks session

    % for each the contrast, get the trls we need and save a new file
    for c = n,
        [~, name]    = getContrastIdx([], c);
        
        for l = 1:length(locks),

        	% skip if this exists
        	if exist(sprintf('%s/P%02d-S%d_evoked_%s_%s.mat', ...
                subjectdata.tfrdir, sj, session, locks{l}, name), 'file'),
        		continue
        	else 
        		fprintf('starting %s/P%02d-S%d_evoked_%s_%s.mat \n', ...
                subjectdata.tfrdir, sj, session, locks{l}, name)
        	end

		    % get the for the baseline
        	if ~exist('commonbl', 'var'),
			    load(sprintf('%s/P%02d-S%d_all_ref.mat', subjectdata.tfrdir, sj, session));
			    try; freq = rmfield(freq, 'cfg'); end
			        
			    % samples 5, 6 and 7 are -250ms, -200ms, -150ms
			    catbl = cat(1, freq.powspctrm(:, :, :, 5), ...
			        freq.powspctrm(:, :, :, 6), freq.powspctrm(:, :, :, 7));
			    commonbl = nanmean(catbl);
			    clear freq;
			end

			% get the data to work with
            load(sprintf('%s/P%02d-S%d_%s.mat', subjectdata.lockdir, sj, session, locks{l}));
            alldata = data;
            
            % ==================================================================
            % BASELINE CORRECT SINGLE TRIAL EVENT-RELATED FIELDS
            % ==================================================================
            
            [trls, name]    = getContrastIdx(alldata.trialinfo, c);
                    
            % % average over trials in the time domain
            % cfg             = [];
            % cfg.trials      = trls;
            % cfg.keeptrials  = 'yes';
            % cfg.feedback    = 'none';
            % data            = ft_timelockanalysis(cfg, alldata);
            
            % % run the frequency analysis, same as for induced power
            % freq     = tfr_runFreqAnalysis(data);
                    
            % average over trials in the time domain
            cfg             = [];
            cfg.trials      = trls;
            cfg.keeptrials  = 'no';
            cfg.feedback    = 'none';
            data            = ft_timelockanalysis(cfg, alldata);
            
            % run the frequency analysis, same as for induced power
            freq            = tfr_runFreqAnalysis(data);
                           
            % ==================================================================
            % BASELINE CORRECT frequency spectrum
            % ==================================================================
            
            percchange = @(pow, bl) 100 .* (pow - bl) ./ bl;
            tic; freq.powspctrm = bsxfun(percchange, freq.powspctrm, commonbl); toc;

            % ==================================================================
            % remove trial dimension
            % ==================================================================
            
            freq = ft_freqdescriptives([], freq);
            freq = rmfield(freq, 'cfg');
            
            % save
            savefast(sprintf('%s/P%02d-S%d_evoked_%s_%s.mat', ...
                subjectdata.tfrdir, sj, session, locks{l}, name), 'freq');
            
        end
    end
    end

    toc;
end
