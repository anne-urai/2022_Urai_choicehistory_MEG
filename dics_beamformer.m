function dics_beamformer(sj, sessions, vs, ls)
% Beamforms predefined frequency bands

if ~isdeployed,
    addpath(genpath('~/code/MEG'));
    addpath(genpath('~/code/Tools'));
    addpath('~/Documents/fieldtrip');
    ft_defaults;  % ft_defaults should work in deployed app?
end

% ==================================================================
% LOAD IN SUBJECT SPECIFICS AND READ DATA
% ==================================================================

close all;

if ischar(sj), sj = str2double(sj); end
subjectdata = subjectspecifics(sj);

if ~exist('sessions', 'var'), sessions = [1:length(subjectdata.session)]; end
if ischar(sessions), sessions = str2double(sessions); end

freqs  = dics_freqbands; % retrieve specifications
if ~exist('vs', 'var'), vs = [1:length(freqs)]; end
if ischar(vs), vs = str2double(vs); end

% lockings
if ~exist('ls', 'var'), ls = [1:4]; end
if ischar(ls), ls = str2double(ls); end

for session = sessions,
    
    % get pre-computed headmodel
    mri = load(sprintf('%s/P%02d_headmodel.mat', subjectdata.mridir, sj));
    mri.headmodel = rmfield(mri.headmodel, 'cfg');

    % load data
    load(sprintf('%s/P%02d-S%d_cleandata.mat', ...
        subjectdata.preprocdir, sj, session));
    data.grad   = data.grad_first;
    grad        = data.grad_first;
    data        = rmfield(data, {'grad_first', 'grad_avg', 'grad_all'});
    
    % load leadfields
    lf = load(sprintf('%s/P%02d-S%d_leadfields_firstgrad.mat', ...
        subjectdata.mridir, sj, session));
    fprintf('\n BEAMFORMING subject %d, session %d \n', sj, session);
    
    for v = vs,

        % ==================================================================
        % CREATE A SLIDING WINDOW - loop over lockings
        % ==================================================================
        
        locking(1).name         = 'ref';
        locking(1).prestim      = 0.5;
        locking(1).poststim     = 1.5;
        locking(2).name         = 'stim';
        locking(2).prestim      = 0.5;
        locking(2).poststim     = 1;
        locking(3).name         = 'resp';
        locking(3).prestim      = 0.5;
        locking(3).poststim     = 1.5;
        locking(4).name         = 'fb';
        locking(4).prestim      = 0.5;
        locking(4).poststim     = 1.5;
        
        for l = ls,

            % ==============================
            % don't redo if this already exists
            % ===============================
            
            filename = sprintf('%s/P%02d-S%d_dics_%s_%s.mat', ...
                subjectdata.sourcedir, sj, session, freqs(v).name, locking(l).name);
            if exist(filename, 'file'),
                try % test if this file is not corrupted!
                    load(filename);
                    fprintf('\nSkipping %s/P%02d-S%d_dics_%s_%s.mat, already exists \n', ...
                        subjectdata.sourcedir, sj, session, freqs(v).name, locking(l).name);
                    continue;
                catch
                	fprintf('\nDeleting %s/P%02d-S%d_dics_%s_%s.mat, corrupted \n', ...
                        subjectdata.sourcedir, sj, session, freqs(v).name, locking(l).name);
                    delete(filename);
                end
            end
                	
            % ==================================================================
            % MAKE COMMON FILTER
            % ==================================================================
            
            % only use the time before the end of the second trial -> clean
            data_common                 = ft_selectdata({'latency', [0 1.99], 'avgovertime', 'no'}, data);
            data_common                 = ft_timelockanalysis(struct('keeptrials', 'yes'), data_common);
            data_common                 = rmfield(data_common, 'cfg');
            
            cfg                         = [];
            cfg.method                  = 'mtmfft';
            cfg.output                  = 'powandcsd';
            cfg.taper                   = 'dpss';
            cfg.channel                 = ft_channelselection('MEG', data_common.label);
            cfg.keeptrials              = 'yes'; % work with all trials throughout
            cfg.keeptapers              = 'no';
            cfg.precision               = 'single'; % saves disk space
            cfg.foi                     = freqs(v).freq;
            cfg.tapsmofrq               = freqs(v).tapsmofrq;
            cfg.pad                     = 2; % to speed up computation
            cfg.feedback                = 'none'; % keep logfiles clean
            freq_common                 = ft_freqanalysis(cfg, data_common);
            
            assert(freq_common.freq == freqs(v).freq, 'intended frequency could not be recovered');
            
            cfg                         = [];
            cfg.method                  = 'dics';
            cfg.sourcemodel             = lf.leadfield;            % should be grid defined in MNI space
            cfg.headmodel               = mri.headmodel;            % previously computed volume conduction model
            cfg.frequency               = freq_common.freq;
            cfg.dics.keepfilter         = 'yes';                % remember the filter
            cfg.dics.lambda             = '10%';                % higher lambda is sparses source estimate?
            cfg.dics.realfilter         = 'yes';
            cfg.dics.fixedori           = 'yes';                % if fixedori = no, get 3 directions for each grid point
            cfg.dics.projectnoise       = 'yes';                % for baseline vs activity
            cfg.dics.feedback           = 'none';
            common_filter               = ft_sourceanalysis(cfg, freq_common); % use concatenated data

            % PRE-ALLOCATE THE OUTPUT STRUCTURE
            source = struct('freq', freq_common.freq, ...
                'dim', common_filter.dim, ...
                'inside', common_filter.inside, ...
                'pos', common_filter.pos, ...
                'method', 'rawtrial', ...
                'powdimord', 'pos_rpt_time', ...
                'trialinfo', data.trialinfo);
            
            % ==============================
            % get locked data
            % ===============================
            
            data_lock = dics_redefinetrials(data, l);
            
            % make nice timebins at each 50 ms, will include 0 point
            timestep = 0.05; % in seconds
            toi = -locking(l).prestim : timestep : locking(l).poststim;
            
            % make sure there are no bins outside the  time in the data
            toi(toi < min(data_lock.time)) = [];
            toi(toi > max(data_lock.time)) = [];
            source.time = toi;
            
            % separate this out for the parfor loop
            pow = nan(size(common_filter.pos, 1), length(data.trial), length(toi));

            % save some memory
            common_filter = common_filter.avg.filter;
            clear freq_common data_common 
            
            for t = 1:length(toi),
                
                fprintf('\n\n Beamforming P%02d-S%d, %d Hz, %s, timewindow %f (%d/%d)... \n', ...
                    sj, session, freqs(v).freq, locking(l).name, toi(t), t, length(toi));
                
                % ==================================================================
                % FREQANALYSIS ON A SMALL TIME WINDOW
                % ==================================================================
                
                tic;
                cfg                         = [];
                thistoi                     = toi(t);           % each of these gets its own loop
                windowlength                = freqs(v).timewin;     % half a second, an integer nr of cycles has to fit in
                cfg.toilim                  = [thistoi-windowlength/2 thistoi+windowlength/2]; % redefine
                data_toi                    = ft_redefinetrial(cfg, data_lock);
                data_toi.grad               = grad;             % make sure this is consistent
                
                assert(all(rem(freqs(v).freq ./ windowlength, 1) == 0), ...
                    'an integer number of cycles must fit into this time window');
                if ~(roundn(data_toi.time(1), -2) == roundn(cfg.toilim(1), -2) ...
                        && roundn(data_toi.time(end), -2) == roundn(cfg.toilim(2), -2)),
                    warning('could not grab the specific timewin intended: %s, %d', locking(l).name, t);
                end
                                
                cfg                         = [];
                cfg.method                  = 'mtmfft';
                cfg.output                  = 'powandcsd';
                cfg.taper                   = 'dpss';
                cfg.channel                 = ft_channelselection('MEG', data_toi.label);
                cfg.keeptrials              = 'yes'; % work with all trials throughout
                cfg.keeptapers              = 'no';
                cfg.precision               = 'single'; % saves disk space
                cfg.foi                     = freqs(v).freq;
                cfg.tapsmofrq               = freqs(v).tapsmofrq;
                cfg.pad                     = 2; % to speed up computation
                cfg.feedback                = 'none'; % keep logfiles clean
                freq_toi                    = ft_freqanalysis(cfg, data_toi);
                assert(freq_toi.freq == freqs(v).freq, 'intended frequency could not be recovered');
                
                % ==================================================================
                % PROJECT ALL TRIALS THROUGH COMMON FILTER
                % ==================================================================
                
                cfg                         = [];
                cfg.method                  = 'dics';
                cfg.headmodel               = mri.headmodel;
                cfg.sourcemodel             = lf.leadfield;
                cfg.sourcemodel.filter      = common_filter;  % use the common filter computed in the previous step!
                
                cfg.dics.keepfilter         = 'no';                  	% remember the filter
                cfg.dics.lambda             = '10%';                 	% higher lambda is sparses source estimate?
                cfg.dics.realfilter         = 'yes';
                cfg.dics.fixedori           = 'yes';                	% if fixedori = no, get 3 directions for each grid point
                cfg.dics.projectnoise       = 'yes';                	% for baseline vs activity
                cfg.dics.feedback           = 'text';                   % keep logfiles clean
                cfg.frequency               = freq_toi.freq;
                
                cfg.rawtrial                = 'yes'; % project each single trial through the filter
                cfg.keeptrial               = 'no'; % dont keep trialinfo struct, can copy from data
                source_toi                  = ft_sourceanalysis(cfg, freq_toi);
                assert(source_toi.freq == freqs(v).freq, 'intended frequency could not be recovered');
                
                % save this output in the large 3-d matrix
                pow(:, :, t)                = [source_toi.trial(:).pow];
                toc;
            end % toi
            
            source.pow       = pow;

            % SAVE
            savefast(sprintf('%s/P%02d-S%d_dics_%s_%s.mat', ...
                subjectdata.sourcedir, sj, session, freqs(v).name, locking(l).name), 'source');
            fprintf('\nSAVED %s/P%02d-S%d_dics_%s.mat \n\n', ...
                subjectdata.sourcedir, sj, session, freqs(v).name , locking(l).name);
            
            end % lockings
    end % freqs
end % sessions

end
