function [] = tfr_grandAverage(whichIdx, whichSession, doERF, doTFR, doEvoked)
% select subsets of trials that we'll look at and compare,

if ~isdeployed,
    addpath(genpath('~/code/MEG'));
    addpath(genpath('~/code/Tools'));
    addpath('~/Documents/fieldtrip');
    ft_defaults;  % ft_defaults should work in deployed app?
end

% set defaults
if ~exist('doERF', 'var'),          doERF = 0;
end
if ~exist('doTFR', 'var'),          doTFR = 1;
end
if ~exist('doEvoked', 'var'),       doEvoked = 0;
end
if ~exist('whichIdx', 'var'),       whichIdx = 1:31;
end
if ~exist('whichSession', 'var'),   whichSession = [1 2];
end

% stopos
if ischar(whichIdx), whichIdx           = str2double(whichIdx);
end
if ischar(whichSession), whichSession   = str2double(whichSession);
end
if ischar(doERF), doERF                 = str2double(doERF);
end
if ischar(doTFR), doTFR                 = str2double(doTFR);
end
if ischar(doEvoked), doEvoked           = str2double(doEvoked);
end

% define subjects
GAdata = subjectspecifics('GA');
groups = {'all', 'placebo', 'atomoxetine', 'donepezil'};
groups = {'all', 'repeaters', 'alternators'};

% only use subjects with enough MEG trials
groups = {'clean'};
locks  = {'ref', 'stim', 'resp', 'fb'}; % for all the lockings

for g = 1:length(groups),
    
    % find the list of those subjects
    subjects = unique(GAdata.(groups{g}));
    
    % ==================================================================
    % ERFs
    % ==================================================================
    
    if doERF,
        for session = whichSession,
            for l = 1:length(locks),
                for c = whichIdx,
                    
                    [~, name] = getContrastIdx([], c);
                    cfg = []; cfg.inputfile = {};
                    
                    % get data from all subjects
                    for sj = subjects,
                        subjectdata = subjectspecifics(sj);
                        
                        ff = sprintf('%s/P%02d-S%d_bl_%s_%s.mat', ...
                            subjectdata.lockdir, sj, session, locks{l}, name);
                        if exist(ff, 'file'),
                            cfg.inputfile{end+1} = ff;
                        end
                    end
                    
                    % grand average file
                    cfg.keepindividual = 'yes';
                    cfg.parameter      = 'avg';
                    cfg.outputfile     = sprintf('%s/GA%s-S%d_lockbl_%s_%s.mat', ...
                        GAdata.lockdir, groups{g}, session, locks{l}, name);
                    ft_timelockgrandaverage(cfg);
                end
            end
        end
    end
    
    % ==================================================================
    % TFRs - induced
    % ==================================================================
    
    if doTFR,
        for session = whichSession,
            for c = whichIdx,
                [~, name] = getContrastIdx([], c);
                
                for l = 1:length(locks),
                    
                    cfg = [];
                    cfg.inputfile = {};
                    
                    % get data from all subjects
                    for sj = subjects,
                        subjectdata = subjectspecifics(sj);

                        ff = sprintf('%s/P%02d-S%d_bl_%s_%s.mat', ...
                            subjectdata.tfrdir, sj, session, locks{l}, name);
                        if exist(ff, 'file'),
                            cfg.inputfile{end+1} = ff;
                        end
                    end
                    
                    % grand average file - for plots
                    cfg.keepindividual = 'no';
                    cfg.parameter      = 'powspctrm'; % can contain the avg or var, depends on filename
                    cfg.outputfile     = sprintf('%s/GA%s-S%d_freqbl_%s_%s.mat', ...
                        GAdata.tfrdir, groups{g}, session, locks{l}, name);
                    ft_freqgrandaverage(cfg);
                    
                    % also with all individuals, for stats
                    cfg.keepindividual = 'yes';
                    cfg.outputfile     = sprintf('%s/GA%s-S%d_freqbl_%s_%s_allindividuals.mat', ...
                        GAdata.tfrdir, groups{g}, session, locks{l}, name);
                    ft_freqgrandaverage(cfg);
                    
                end
                
                % % ALSO INCLUDE THE POWER BASELINE
                % cfg             = [];
                % cfg.inputfile   = {};
                % for sj = subjects,
                %     subjectdata = subjectspecifics(sj);

                %     ff = sprintf('%s/P%02d-S%d_rawbaseline_%s.mat', ...
                %     subjectdata.tfrdir, sj, session, name);
                %     if exist(ff, 'file'),
                %         cfg.inputfile{end+1} = ff;
                %     end

                % end
                % cfg.keepindividual = 'yes';
                % cfg.parameter      = 'powspctrm'; % can contain the avg or var, depends on filename
                % cfg.outputfile     = sprintf('%s/GA%s-S%d_rawbaseline_%s_allindividuals.mat', ...
                %     GAdata.tfrdir, groups{g}, session, name);
                % ft_freqgrandaverage(cfg);
                
                % % AND NORMALIZED
                % cfg.inputfile   = {};
                % for sj = subjects,
                %     subjectdata = subjectspecifics(sj);

                %     ff = sprintf('%s/P%02d-S%d_normalizedbaseline_%s.mat', ...
                %         subjectdata.tfrdir, sj, session, name);
                %     if exist(ff, 'file'),
                %         cfg.inputfile{end+1} = ff;
                %     end

                % end
                % cfg.outputfile     = sprintf('%s/GA%s-S%d_normalizedbaseline_%s_allindividuals.mat', ...
                %     GAdata.tfrdir, groups{g}, session, name);
                % ft_freqgrandaverage(cfg);
                
            end
        end
    end
    
    % ==================================================================
    % TFRs - evoked
    % ==================================================================
    
    if doEvoked,
        for session = whichSession,
            for l = 1:2, % only during stimulus
                for c = whichIdx,
                    
                    [~, name] = getContrastIdx([], c);
                    cfg = [];
                    cfg.inputfile = {};
                    
                    % get data from all subjects
                    for sj = subjects,
                        subjectdata = subjectspecifics(sj);        

                        ff = sprintf('%s/P%02d-S%d_evoked_%s_%s.mat', ...
                                subjectdata.tfrdir, sj, session, locks{l}, name);
                        if exist(ff, 'file'),
                            cfg.inputfile{end+1} = ff;
                        end

                    end
                    
                    % grand average file
                    cfg.keepindividual = 'no';
                    cfg.parameter      = 'powspctrm'; % can contain the avg or var, depends on filename
                    cfg.outputfile     = sprintf('%s/GA%s-S%d_evoked_%s_%s.mat', ...
                        GAdata.tfrdir, groups{g}, session, locks{l}, name);
                    ft_freqgrandaverage(cfg);
                    
                    % also with all individuals, for stats
                    cfg.keepindividual = 'yes';
                    cfg.outputfile     = sprintf('%s/GA%s-S%d_evoked_%s_%s_allindividuals.mat', ...
                        GAdata.tfrdir, groups{g}, session, locks{l}, name);
                    ft_freqgrandaverage(cfg);
                end
            end
        end
    end
    
end

disp('DONE');
end
