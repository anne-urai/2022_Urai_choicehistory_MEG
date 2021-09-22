function [] = tfr_contrasts(sj, sessions, n)
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

% ==================================================================
% LOAD IN SUBJECT SPECIFICS AND READ DATA
% ==================================================================

if ischar(sj), sj = str2double(sj); end
subjectdata = subjectspecifics(sj);
if ~exist('sessions', 'var'), sessions = [1:length(subjectdata.session) 0]; end
if ischar(sessions), sessions = str2double(sessions); end

if ~exist('n', 'var'), n = [1:25]; end
if ischar(n), n = str2double(n); end

locks = {'ref', 'stim', 'resp', 'fb'};

% =======================================
% go through all the files
% =======================================

for session = sessions,
    
    % ==================================================================
    % GET CONTRASTS FOR PLOTTING
    % ==================================================================
    
    for l = 1:length(locks),

        % plot with common baseline
        load(sprintf('%s/P%02d-S%d_commonbl_%s.mat', subjectdata.tfrdir, sj, session, locks{l}));
        fprintf('%s/P%02d-S%d_commonbl_%s.mat \n', subjectdata.tfrdir, sj, session, locks{l});

        % remove Nan parts of the data
        cfg             = [];
        timecourse      = squeeze(nanmean(nanmean(nanmean(freq.powspctrm))));
        cfg.latency     = [freq.time(find(~isnan(timecourse), 1, 'first')) ...
            freq.time(find(~isnan(timecourse), 1, 'last'))];
        alldata         = ft_selectdata(cfg, freq);
        
        % for all the contrasts, get the trls we need and save a new file
        for c = n,
            
            [trls, name]    = getContrastIdx(alldata.trialinfo, c);
            
            if isempty(trls), 
                fprintf(sprintf('NO TRIALS, FAILED: %s/P%02d-S%d_bl_%s_%s.mat \n', ...
                    subjectdata.tfrdir, sj, session, locks{l}, name))
                continue; 
            end

            if ~exist(sprintf('%s/P%02d-S%d_bl_%s_%s.mat', ...
                    subjectdata.tfrdir, sj, session, locks{l}, name), 'file'),
                cfg             = [];
                cfg.trials      = trls;
                cfg.keeptrials  = 'no'; % these files will be tiny
                freq            = ft_freqdescriptives(cfg, alldata);
                freq            = rmfield(freq, 'cfg');
                
                savefast(sprintf('%s/P%02d-S%d_bl_%s_%s.mat', ...
                    subjectdata.tfrdir, sj, session, locks{l}, name), 'freq');
                fprintf('%s/P%02d-S%d_bl_%s_%s.mat \n', ...
                    subjectdata.tfrdir, sj, session, locks{l}, name);
            end
        end
    end
    
    % % ========================== %
    % % ALSO FOR BASELINE SPECTRA
    % % ========================== %
    
    % load(sprintf('%s/P%02d-S%d_baseline.mat', subjectdata.tfrdir, sj, session));
    
    % % for all the contrasts, get the trls we need and save a new file
    % for c = n,
        
    %     [trls, name]    = getContrastIdx(bl.trialinfo, c);
    %     if isempty(trls), continue; end

    %     if ~exist(sprintf('%s/P%02d-S%d_normalizedbaseline_%s.mat', ...
    %         subjectdata.tfrdir, sj, session, name), 'file'),
    %         disp(name);
    %         cfg             = [];
    %         cfg.trials      = trls;
    %         cfg.keeptrials  = 'no'; % these files will be tiny
            
    %         rawbl         	= bl;
    %         rawbl.powspctrm = rawbl.raw;
    %         freq            = ft_freqdescriptives(cfg, rawbl);
    %         freq            = rmfield(freq, 'cfg');
            
    %         savefast(sprintf('%s/P%02d-S%d_rawbaseline_%s.mat', ...
    %             subjectdata.tfrdir, sj, session, name), 'freq');
            
    %         % AND FOR THE NORMALIZED BL
    %         rawbl         	= bl;
    %         rawbl.powspctrm = rawbl.normalized;
    %         freq            = ft_freqdescriptives(cfg, rawbl);
    %         freq            = rmfield(freq, 'cfg');
            
    %         savefast(sprintf('%s/P%02d-S%d_normalizedbaseline_%s.mat', ...
    %             subjectdata.tfrdir, sj, session, name), 'freq');
    %     end

    % end
end
fprintf('\n DONE P%02d \n', sj);

end
