function [] = preproc_readMEG(sj)
% Read in and apply preprocessing to the data from one subject
% 1. read in continuous data, only the chans we need
% 2. downsample to 400 Hz
% 3. match eyelink files
% 4. epoch into trials

if ~isdeployed,
    addpath(genpath('~/code/MEG'));
    addpath(genpath('~/code/Tools'));
    addpath('~/Documents/fieldtrip');
    ft_defaults; warning off;
end

if ischar(sj), sj = str2double(sj); end

% ==================================================================
% LOAD IN SUBJECT SPECIFICS AND READ DATA
% ==================================================================

subjectdata = subjectspecifics(sj);

for session = 1:length(subjectdata.session),
    disp(['Analysing subject ' num2str(sj) ', session ' num2str(session)]);
    
    for rec = subjectdata.session(session).recsorder,
        clearvars -except sj session subjectdata rec
        
        if exist(sprintf('%s/P%02d-S%d_rec%d_data.mat', ...
                subjectdata.preprocdir, sj, session, rec), 'file'),
            %  continue;
        end
        
        % ==================================================================
        % READ IN CONTINUOUS DATA
        % ==================================================================
        
        % read in the dataset as a continuous segment
        disp(subjectdata.session(session).rec(rec).dataset);
        cfg                         = [];
        cfg.dataset                 = sprintf('%s/%s', subjectdata.rawdir, ...
            subjectdata.session(session).rec(rec).dataset);
        cfg.continuous              = 'yes'; % read in the data
        cfg.precision               = 'single'; % for speed and memory issues
        cfg.sj                      = sj;
        cfg.session                 = session;
        cfg.rec                     = rec;
        cfg.detrend                 = 'no';
        cfg.demean                  = 'yes';
        
        % preselect only those channels that are useful
        % for testing, restrict the subset of MEG sensors
        cfg.channel                 = {'M*', ...
            'EEG001', 'EEG006', 'EEG012', 'EEG018', 'EEG024', 'EEG059', ...
            'HLC*', 'UPPT*', 'UADC*'};
        data = ft_preprocessing(cfg);
        
        % ==================================================================
        % RENAME AND REREF EEG CHANS
        % ==================================================================
        
        data.label = strrep(data.label, 'EEG001', 'EOGright');
        data.label = strrep(data.label, 'EEG006', 'EOGleft');
        data.label = strrep(data.label, 'EEG012', 'EOGtop');
        data.label = strrep(data.label, 'EEG018', 'EOGbottom');
        data.label = strrep(data.label, 'EEG024', 'POz');
        data.label = strrep(data.label, 'EEG059', 'EKG');
        data.label = strrep(data.label, 'UADC002', 'EYEH');
        data.label = strrep(data.label, 'UADC003', 'EYEV');
        data.label = strrep(data.label, 'UADC004', 'EYEPUPIL');
        
        % rereference horizontal EOG chans
        data.trial{1}(find(~cellfun(@isempty, strfind(data.label, 'EOGright'))), :) = ...
            data.trial{1}(find(~cellfun(@isempty, strfind(data.label, 'EOGright'))), :) - ...
            data.trial{1}(find(~cellfun(@isempty, strfind(data.label, 'EOGleft'))), :);
        data.label = strrep(data.label, 'EOGright', 'EOGH'); % rename
        
        % rereference vertical EOG chans
        data.trial{1}(find(~cellfun(@isempty, strfind(data.label, 'EOGtop'))), :) = ...
            data.trial{1}(find(~cellfun(@isempty, strfind(data.label, 'EOGtop'))), :) - ...
            data.trial{1}(find(~cellfun(@isempty, strfind(data.label, 'EOGbottom'))), :);
        data.label = strrep(data.label, 'EOGtop', 'EOGV'); % rename
        
        % remove the chans we dont need anymore
        cfg             = [];
        cfg.channel     = {'all', '-EOGbottom', '-EOGleft'};
        data            = ft_preprocessing(cfg, data);
        data            = rmfield(data, 'cfg'); % keep it small
        
        % ==================================================================
        % DOWNSAMPLE
        % ==================================================================
        
        oldfs           = 1200; % original sampling rate of all recordings
        newfs           = 400; % 1/3rd the MEG sampling rate, can still see up to 120 Hz gamma
        assert(data.fsample == oldfs, 'MEG data not collected at 1200 Hz');
        
        cfg             = [];
        cfg.resamplefs  = newfs;
        cfg.detrend     = 'no'; % dont detrend if i want to look at cpp
        cfg.demean      = 'yes'; % will subtract the baseline = mean of all data
        data            = ft_resampledata(cfg, data);
        
        % ==================================================================
        % PARSE EVENTS
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
        
        cfg.trialdef.pre        = 0.51; % before reference start (including fix)
        cfg.trialdef.post       = 2; % after feedback
        cfg.sj                  = sj;
        cfg.session             = session;
        cfg.rec                 = rec;
        cfg 					= ft_definetrial(cfg); % define all trials
        
        % check that this doesn't lead to overlapping trials
        for t = 1:size(cfg.trl, 1)-1,
            assert(cfg.trl(t, 2) < cfg.trl(t+1, 1), 'wrong');
        end
        
        % downsample the sample idx
        newfs                   = 400;
        samplerows              = find(mean(cfg.trl) > 100);
        cfg.trl(:,samplerows)   = round(cfg.trl(:,samplerows) * (newfs/oldfs));
        
        % add a unique idx at the end
        % subject, session, block, trialnr
        idx = sj * 1000000 + cfg.trl(:, 17) * 10000 ...
            + cfg.trl(:, 16) * 100 + cfg.trl(:, 15);
        % make sure all idx are unique
        assert(numel(unique(idx)) == length(idx), 'idx needs to be unique!');
        cfg.trl(:, end+1) = idx;
        
        % will use this to match EL and motionenergy
        trialdefinition         = cfg.trl;
        
        % ==================================================================
        % DO A CHECK ON THE BLOCK NRS
        % ==================================================================
        
        nrtrls  = size(trialdefinition, 1);
        nblocks = length(subjectdata.session(session).rec(rec).blocks);
        
        % check if there are known missing trials from this dataset
        missingtrials = [];
        for b = subjectdata.session(session).rec(rec).blocks,
            try % see if there are known missed trials
                missingtrials = [missingtrials ...
                    subjectdata.session(session).rec(rec).block(b).missingtrials];
            end
        end
        assert((nrtrls+length(missingtrials))/60 == nblocks, ...
            'mistake in subjectspecifics');
        
        % % ==================================================================
        % % MATCH WITH EYELINK
        % % ==================================================================
        
        % recdate = regexp(subjectdata.session(session).rec(rec).dataset, '201\d*', 'match');
        % recdate = datenum(recdate{1}, 'yyyymmdd');
        
        % % when no eyelink was recorded, fill those chans with zeros
        % if recdate < datenum('20140515', 'yyyymmdd') || ...
        %         (sj == 6 && session == 1) || ...
        %         (sj == 31 && session == 2 && rec == 2),
            
        %     % zeros may mess up the statistics!
        %     disp('No EyeLink recorded, filling with NaNs');
        %     eyechans = find(~cellfun(@isempty, strfind(data.label, 'EYE')));
        %     for e = 1:length(eyechans),
        %         data.trial{1}(eyechans(e), :) = nan(1, size(data.trial{1}, 2));
        %     end
        % else
        %     % ==================================================================
        %     % GET DATA FROM EYELINK
        %     % ==================================================================
            
        %     % on 13-07-2015, we installed the analogue link so afterwards
        %     % the eyelink channels are already there
        %     if recdate < datenum('20150713', 'yyyymmdd'), replace = 1;
        %     else replace = 0; end
            
        %     for b = subjectdata.session(session).rec(rec).blocks,
                
        %         % get the right session nr
        %         if session == 2, thissession = 5;
        %         elseif session == 1, thissession = 1; end
                
        %         % convert edf to asc if needed
        %         ascFile = dir(sprintf('%s/EL_P%d_s%d_b%d_*.asc', subjectdata.eyedir, sj, thissession, b));
        %         if isempty(ascFile),
        %             edfFile = dir(sprintf('%s/EL_P%d_s%d_b%d_*.edf', subjectdata.eyedir, sj, thissession, b));
        %             edfFile = sprintf('%s/%s', subjectdata.eyedir, edfFile.name);
        %             system(sprintf('%s %s -input -failsafe', '~/code/Tools/eye/edf2asc-linux', edfFile)); % failsafe mode for corrupted edfs
        %             ascFile = dir(sprintf('%s/EL_P%d_s%d_b%d_*.asc', subjectdata.eyedir, sj, thissession, b));
        %         end
                
        %         % read in asc file from disk
        %         assert(length(ascFile) == 1);
        %         asc = read_eyelink_ascNK_AU([subjectdata.eyedir '/' ascFile.name]);
                
        %         % workaround for lost messages: retrieved from fixtime and ref timestamp
        %         if sj == 10 && session == 1 && b == 1,
        %             timestamp = round(15889758 - 0.6380*1000);
        %             asc.msg{77} = ['MSG ' num2str(timestamp) ' block1_trial6_fix'];
        %         elseif sj == 10 && session == 1 && b == 5,
        %             timestamp = round(19429421 - 0.8162*1000);
        %             asc.msg{37} = ['MSG ' num2str(timestamp) ' block5_trial1_fix'];
        %         elseif sj == 11 && session == 1 && b == 1,
        %             timestamp = round(2179361 - 0.8530*1000);
        %             asc.msg{57} = ['MSG ' num2str(timestamp) ' block1_trial4_fix'];
        %         elseif sj == 19 && session == 1 && b == 1,
        %             timestamp = round(10810223 - 0.5788*1000);
        %             asc.msg{45} = ['MSG ' num2str(timestamp) ' block1_trial2_fix'];
        %         end
                
        %         % match to MEG data
        %         cfg                 = [];
        %         cfg.sj              = sj;
        %         cfg.session         = session;
        %         cfg.rec             = rec;
        %         cfg.block           = b;
        %         data                = pupil_syncEyeMEG(cfg, data, trialdefinition, asc, replace, 0);
        %     end
            
        %     % ==================================================================
        %     % show the resulting pupil signal for the whole recording
        %     % ==================================================================
            
        %     clf;
        %     xlimrange = linspace(data.time{1}(1), data.time{1}(end), ...
        %         length(subjectdata.session(session).rec(rec).blocks)+1);
        %     for sp = 1:length(xlimrange)-1,
        %         subplot(7,1,sp);
        %         plot(data.time{1}, (data.trial{1}(find(~cellfun(@isempty, ...
        %             strfind(lower(data.label), 'eyepupil'))), :)));
        %         % define range
        %         xlim([xlimrange(sp) xlimrange(sp+1)]);
        %         ylim([-4 4]); box off; % zscored, so plot plausible range
        %         set(gca, 'tickdir', 'out');
        %         if sp == 1, title(sprintf('P%02d-S%d_rec%d', sj, session, rec), 'interpreter', 'none'); end
        %     end
        %     suplabel('Pupil signal (z)', 'y');
        %     print(gcf, '-dpdf', ...
        %         sprintf('%s/P%02d-S%d_rec%d_finalpupil.pdf', subjectdata.figsdir, ...
        %         sj, session, rec));
        % end
        
        % ==================================================================
        % EPOCH INTO TRIALS
        % ==================================================================
        
        % load(sprintf('%s/P%02d-S%d_rec%d_contdata.mat', ...
        %    subjectdata.preprocdir, sj, session, rec));
        assert(data.fsample == newfs, 'sampling rate error');
        
        cfg                     = [];
        cfg.trl                 = trialdefinition;
        data 					= ft_redefinetrial(cfg, data);
        
        % ==================================================================
        % SAVE FILE
        % ==================================================================
        
        data    = rmfield(data, 'cfg'); % keep the data file as small as possible
        savefast(sprintf('%s/P%02d-S%d_rec%d_data.mat', ...
            subjectdata.preprocdir, sj, session, rec), 'data', 'trialdefinition');
        fprintf('\n\n SAVED %s/P%02d-S%d_rec%d_data.mat \n\n', ...
            subjectdata.preprocdir, sj, session, rec);
        
    end % recordings
end % session

end
