function [] = heartrate_preprocess(subjects)
% for each file, read in the full timecourse of channel EEG059 and compute
% heart rate. Then compare this over the two sessions, for each drug group

addpath(genpath('~/code/MEG'));
addpath('~/Documents/fieldtrip/');
ft_defaults; warning off;

subjectdata = subjectspecifics('ga');
subjects    = subjectdata.all;
if ~exist('subjects', 'var'), subjects = 2:65; end

for sj = unique(subjects),
    
    % ==================================================================
    % LOAD IN SUBJECT SPECIFICS AND READ DATA
    % ==================================================================
    
    subjectdata = subjectspecifics(sj);
    
    for session = 1:length(subjectdata.session),
        disp(['Analysing subject ' num2str(sj) ', session ' num2str(session)]);
        for rec = subjectdata.session(session).recsorder,
            
            % read in the dataset as a continuous segment
            cfg                         = [];
            cfg.dataset                 = sprintf('%s/%s', subjectdata.rawdir, ...
                subjectdata.session(session).rec(rec).dataset);
            cfg.continuous              = 'yes'; % read in the data
            cfg.channel                 = 'EEG059'; % only the EKG channel, bipolar
            cfg.sj                      = sj;
            cfg.session                 = session;
            cfg.precision               = 'single';
            cfg.rec                     = rec;
            data                        = ft_preprocessing(cfg);
            
            % ==================================================================
            % DOWNSAMPLE
            % ==================================================================
            
            newfs           = 1000; 
            oldfs           = data.fsample;
            cfg             = [];
            cfg.resamplefs  = newfs;
            cfg.detrend     = 'yes'; % good for avoiding edge artifacts in TFR
            cfg.demean      = 'yes'; % will subtract the baseline = mean of each full trial
            data            = ft_resampledata(cfg, data);
            
            % ==================================================================
            % DEFINE NORMAL TRIALS
            % ==================================================================
            
            cfg                         = [];
            cfg.dataset                 = sprintf('%s/%s', subjectdata.rawdir, ...
                subjectdata.session(session).rec(rec).dataset);
            cfg.trialfun                = 'trialfun_allevents';
            
            % workaround for the first recording day, not all
            % triggers saved... load in from behav file
            if ismember(sj, [2 3 4 5 27]) && session == 1,
                cfg.trialfun        = 'trialfun_allevents_retrievetimings';
            end
            
            cfg.trialdef.pre        = 0; % before the fixation trigger, to have enough length for padding (and avoid edge artefacts)
            cfg.trialdef.post       = 2; % after feedback
            cfg.sj                  = sj;
            cfg.session             = session;
            cfg.rec                 = rec;
            cfg 					= ft_definetrial(cfg); % define all trials
            
            % downsample the sample idx
            samplerows              = find(mean(cfg.trl) > 100);
            cfg.trl(:,samplerows)   = round(cfg.trl(:,samplerows) * (newfs/oldfs));
            
            % ==================================================================
            % RECOMPUTE TRL MATRIX TO TAKE EACH BLOCK SEPARATELY
            % ==================================================================
            
            trl     = cfg.trl;
            nblocks = unique(trl(:,16));
            clear begsmp endsmp
            
            if any(nblocks > 10), % if there are blocks like 81/82 and 21/22, merge them
                if sj == 8 && session == 1,
                    trl((trl(:, 16) > 20), 16) = 2;
                elseif sj == 35 && session == 2,
                    trl((trl(:, 16) > 80), 16) = 8;
                elseif sj == 54 && session == 1,
                    trl((trl(:, 16) > 80), 16) = 8;
                end
                nblocks = unique(trl(:,16));
            end
            
            for b = unique(nblocks)',
                begsmp(find(b==nblocks)) = trl(find(trl(:,16) == b, 1, 'first'), 1);
                endsmp(find(b==nblocks)) = trl(find(trl(:,16) == b, 1, 'last'), 1);
            end
            
            newtrl = [begsmp' endsmp' zeros(length(nblocks), 1)];
            newtrl(begsmp==endsmp, :) = [];
            cfg                 = [];
            cfg.trl             = newtrl; % replace
            cfg.outputfile      = sprintf('~/Data/MEG-PL/EKG/P%02d-S%d_rec%d_ekg.mat', sj, session, rec);
            ft_redefinetrial(cfg, data);
            
        end % recordings
        
        % ==================================================================
        % APPEND
        % ==================================================================
        
        cd('~/Data/MEG-PL/EKG');
        files = dir(sprintf('P%02d-S%d*rec*_ekg.mat', sj, session));
        
        cfg                 = [];
        cfg.inputfile       = {files(:).name};
        cfg.outputfile      = sprintf('P%02d-S%d_ekg.mat', sj, session);
        
        if length(cfg.inputfile) == 1,
            copyfile(files.name, cfg.outputfile);
        else
            ft_appenddata(cfg);
        end
        
        if sj == 54 && session == 1,
            
            load(cfg.outputfile);
            data2.label = data.label;
            data2.fsample = data.fsample;
            data2.cfg = data.cfg;
            
            data2.trial = [data.trial(1:7) ...
                cat(2, data.trial{8:9}) ...
                data.trial(10:11)];
            newtime = cat(2, data.time{8:9});
            newtime = 0.01:1/data.fsample:(numel(newtime)/data.fsample);
            
            data2.time = [data.time(1:7) ...
                newtime ...
                data.time(10:11)];
            
            data = data2;
            for i = 1:10, assert(length(data.time{i}) == length(data.trial{i})); end
            savefast(cfg.outputfile, 'data');
            
        elseif sj == 58  && session == 2,
            
            load(cfg.outputfile);
            data2.label = data.label;
            data2.fsample = data.fsample;
            data2.cfg = data.cfg;
            
            data2.trial = [data.trial(1) ...
                cat(2, data.trial{2:3}) ...
                data.trial(4:11)];
            newtime = cat(2, data.time{2:3});
            newtime = 0.01:1/data.fsample:(numel(newtime)/data.fsample);
            
            data2.time = [data.time(1) ...
                newtime ...
                data.time(4:11)];
            
            data = data2;
            for i = 1:10, assert(length(data.time{i}) == length(data.trial{i})); end
            savefast(cfg.outputfile, 'data');
            
        elseif sj == 63 && session == 1,
            
            load(cfg.outputfile);
            data2.label = data.label;
            data2.fsample = data.fsample;
            data2.cfg = data.cfg;
            
            data2.trial = [data.trial(1:2) ...
                cat(2, data.trial{3:4}) ...
                data.trial(5:11)];
            newtime = cat(2, data.time{3:4});
            newtime = 0.01:1/data.fsample:(numel(newtime)/data.fsample);
            
            data2.time = [data.time(1:2) ...
                newtime ...
                data.time(5:11)];
            
            data = data2;
            for i = 1:10, assert(length(data.time{i}) == length(data.trial{i})); end
            savefast(cfg.outputfile, 'data');
            
        end
        
    end % session
end % subjects
