function [] = tfr_computePow(sj, sessions)
% time-frequency using multitapers
% We used sliding window Fourier transform (Mitra and Pesa- ran 1999)
% (window length: 400 ms, step size: 50 ms) to calculate time-frequency
% representations of the MEG power (spectrograms) for the two gradiometers
% of each sensor and each single trial. We used a single Hanning taper for
% the frequency range 3?35 Hz (frequency resolution: 2.5 Hz, bin size: 1 Hz)
% and the multi-taper technique for the frequency range 36-140 Hz (spectral
% smoothing: 8 Hz, bin size: 2 Hz, 5 tapers). After time-frequency analysis,
% the two orthogonal planar gradiometers of each sensor were combined by
% taking the sum of their power values. Kloosterman et al. (2015)
%
% use decibel instead of % signal change baseline, elss sensitive to large
% outliers

if ~isdeployed,
    addpath(genpath('~/code/MEG'));
    addpath(genpath('~/code/Tools'));
    addpath('~/Documents/fieldtrip');
    ft_defaults;  % ft_defaults should work in deployed app?
end
warning off;

% ==================================================================
% LOAD IN SUBJECT SPECIFICS AND READ DATA
% ==================================================================

if ischar(sj), sj = str2double(sj); end
subjectdata = subjectspecifics(sj);

if ~exist('sessions', 'var'), sessions = [1:length(subjectdata.session) 0]; end
if ischar(sessions), sessions = str2double(sessions); end

% =======================================
% go through all the files
% =======================================

for session = sessions,

    locks = {'ref', 'stim', 'resp', 'fb'};
    
    if session > 0,
    for l = 1:length(locks),
        
        files = {};
        fprintf('\n ANALYSING subject %d, session %d \n\n', sj, session);
        
        % DONT REDO if exists already
        resultsFile = sprintf('%s/P%02d-S%d_%s.mat', ...
            subjectdata.tfrdir, sj, session, locks{l});
        % save filename for appending
        files{end+1} = resultsFile;
        
        if exist(resultsFile, 'file') || exist(sprintf('%s/P%02d-S%d_all_%s.mat', ...
                subjectdata.tfrdir, sj, session, locks{l}), 'file'),
           continue;
        end
        
        load(sprintf('%s/P%02d-S%d_%s.mat', ...
            subjectdata.lockdir, sj, session, rec, locks{l}));
        
        % one function that has all the settings, same for evoked as induced
        freq = tfr_runFreqAnalysis(data);
        savefast(resultsFile, 'freq');
            
    end % locks
    end

    % ==================================================================
    % BASELINE CORRECT WITHIN A SESSION
    % ==================================================================
    
    locks = {'ref', 'stim', 'resp', 'fb'};
    percchange = @(pow, bl) 100 .* (pow - bl) ./ bl;
    
    if session > 0,
        for l = 1:length(locks),
            
            if exist(sprintf('%s/P%02d-S%d_commonbl_%s.mat', subjectdata.tfrdir, sj, session, locks{l}), 'file'),
                continue;
            end

            % COMPUTE ACTUAL BASELINE
            if l == 1 | ~exist('acrosstrialbl', 'var'),

	            % get the data
	            load(sprintf('%s/P%02d-S%d_all_%s.mat', subjectdata.tfrdir, sj, session, locks{1}));
	            try; freq = rmfield(freq, 'cfg'); end
	            
                % samples 5, 6 and 7 are -250ms, -200ms, -150ms. Don't use the first 3 ones!
                catbl = cat(1, freq.powspctrm(:, :, :, 5), ...
                    freq.powspctrm(:, :, :, 6), freq.powspctrm(:, :, :, 7));
                acrosstrialbl = nanmean(catbl);
                
                % save the baseline for each trial!
                rawbaseline         = nanmean(freq.powspctrm(:, :, :, 5:7), 4);
                normalizedbaseline  = bsxfun(percchange, rawbaseline, nanmean(rawbaseline(:)));

                bl.raw              = rawbaseline;
                bl.normalized       = normalizedbaseline;
                bl.trialinfo        = freq.trialinfo;
                bl.dimord           = 'rpt_chan_freq';
                bl.label            = freq.label;
                bl.freq             = freq.freq;
                savefast(sprintf('%s/P%02d-S%d_baseline.mat', subjectdata.tfrdir, sj, session), 'bl');
                fprintf('%s/P%02d-S%d_baseline.mat \n', subjectdata.tfrdir, sj, session)
                
            end

            load(sprintf('%s/P%02d-S%d_all_%s.mat', subjectdata.tfrdir, sj, session, locks{l}));
            try; freq = rmfield(freq, 'cfg'); end
            
            % BASELINE CORRECTION v2 - correct using median over trials, *not* by single trial bl
            tic; freq.powspctrm = bsxfun(percchange, freq.powspctrm, acrosstrialbl); toc;
            savefast(sprintf('%s/P%02d-S%d_commonbl_%s.mat', subjectdata.tfrdir, sj, session, locks{l}), 'freq');
            
        end
    else

        % ==================================================================
        % CONCATENATE THE TWO SESSIONS
        % ==================================================================
        
        for l = 1:length(locks),
            if ~exist(sprintf('%s/P%02d-S%d_commonbl_%s.mat', subjectdata.tfrdir, sj, 0, locks{l}), 'file'),
                s1 = load(sprintf('%s/P%02d-S%d_commonbl_%s.mat', subjectdata.tfrdir, sj, 1, locks{l}));
                
                freq = s1.freq;

                if ismember(sessions, 2), % concatenate if this subject has two sessions
                    s2 = load(sprintf('%s/P%02d-S%d_commonbl_%s.mat', subjectdata.tfrdir, sj, 2, locks{l}));
                    freq.powspctrm = cat(1, s1.freq.powspctrm, s2.freq.powspctrm);
                    freq.trialinfo = cat(1, s1.freq.trialinfo, s2.freq.trialinfo);
                end

                savefast(sprintf('%s/P%02d-S%d_commonbl_%s.mat', subjectdata.tfrdir, sj, 0, locks{l}), 'freq');
                fprintf('%s/P%02d-S%d_commonbl_%s.mat \n', subjectdata.tfrdir, sj, 0, locks{l});
            end
        end
        
        if ~exist(sprintf('%s/P%02d-S%d_baseline.mat', subjectdata.tfrdir, sj, 0), 'file'),
            % also for baseline itself
            s1 = load(sprintf('%s/P%02d-S%d_baseline.mat', subjectdata.tfrdir, sj, 1));
            bl              = s1.bl;

            if ismember(sessions, 2), % concatenate if this subject has two sessions
                s2 = load(sprintf('%s/P%02d-S%d_baseline.mat', subjectdata.tfrdir, sj, 2));
                bl.raw          = cat(1, s1.bl.raw, s2.bl.raw);
                bl.normalized   = cat(1, s1.bl.normalized, s2.bl.normalized);
                bl.trialinfo    = cat(1, s1.bl.trialinfo, s2.bl.trialinfo);
            end
            savefast(sprintf('%s/P%02d-S%d_baseline.mat', subjectdata.tfrdir, sj, 0), 'bl');
        end
        
    end
    fprintf('\n DONE P%02d \n', sj);
    
end
