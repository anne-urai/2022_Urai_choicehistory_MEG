function [] = preproc_redefineFiles(sj, sessions)
% split up the files into reflocked, stimlocked, resplocked and fblocked
% apply ft_megrealign per trial to improve sensor level statistics?

clc; close all;
if ~isdeployed,
    addpath('~/code/MEG');
    addpath(genpath('~/code/Tools'));
    addpath('~/Documents/fieldtrip');
    ft_defaults; % ft_defaults should work in deployed app?
end
warning off;

% ==================================================================
% LOAD IN SUBJECT SPECIFICS AND READ DATA
% ==================================================================

% for running on stopos
if ischar(sj), sj = str2double(sj); end
subjectdata = subjectspecifics(sj);
if ~exist('sessions', 'var'), sessions = 1:length(subjectdata.session); end
if ischar(sessions), sessions = str2double(sessions); end

% ==================================================================
% TIMELOCK DATA
% ==================================================================

for session = sessions,
        
    if ~exist(sprintf('%s/P%02d-S%d_cleandata.mat', ...
            subjectdata.preprocdir, sj, session), 'file'),
        continue
    end

    fprintf('Analysing subject %d, session %d \n', sj, session);
    clearvars -except sj session subjectdata rec;
   
    % ==================================================================
    % APPLY REDEFINETRIAL
    % ==================================================================
    
	locking(1).name         = 'ref';
	locking(2).name         = 'stim';
	locking(3).name         = 'resp';
	locking(4).name         = 'fb';

    for l = 1:length(locking),
        
        if exist(sprintf('%s/P%02d-S%d_%s.mat', ...
                subjectdata.lockdir, sj, session, locking(l).name), 'file'),
            continue;
        end

         % load in this file
    	load(sprintf('%s/P%02d-S%d_cleandata.mat', ...
    	    subjectdata.preprocdir, sj, session));
    	fprintf('loading %s/P%02d-S%d_cleandata.mat \n', ...
    	    subjectdata.preprocdir, sj, session);

    	% ==================================================================
    	% DEFINE INFORMATION ABOUT THE FOUR LOCKINGS
    	% ==================================================================
    	
    	% note: the frequency window is 400 ms long, so 200 ms on either si de
    	% wont be given as time output
    	
    	% with the frequency resolution & padding, subtract 0.25 ms from
    	% the window on either side
    	% maximum epoch is 4, that's what the total padding will be
    	
    	locking(1).offset       = data.trialinfo(:, 2) - data.trialinfo(:, 1);
    	locking(1).prestim      = 0.5; % 500 ms additional time before fixation trigger
    	locking(1).poststim     = 1.49;
    	
    	locking(2).offset       = data.trialinfo(:, 5) - data.trialinfo(:, 1);
    	locking(2).prestim      = 0.5;
    	locking(2).poststim     = 1;
    	% time between stim onset and resp: 0.75-3.75s
    	
    	locking(3).offset       = data.trialinfo(:, 9) - data.trialinfo(:, 1);
    	locking(3).prestim      = 0.5;
    	locking(3).poststim     = 1.49;
    	% time between stim offset and resp: 3s
    	% time between resp and fb: 1.5-3s
    	
    	locking(4).offset       = data.trialinfo(:, 11) - data.trialinfo(:, 1);
    	locking(4).prestim      = 0.5;
    	locking(4).poststim     = 1.49;

    	% ==================================================================
    	% NOW DO THE EPOCHING
    	% ==================================================================
        
        disp(locking(l).name);
        % redefine trials
        % find the samples corresponding to the window we want to see
        cfg                 = [];
        cfg.begsample       = round(locking(l).offset - locking(l).prestim * data.fsample); % take offset into account
        assert(all(cfg.begsample > 0), 'begsample is before onset');
        cfg.endsample       = round(locking(l).offset + locking(l).poststim * data.fsample);
        cfg.offset          = -locking(l).offset;
        data                = redefinetrial(cfg, data);
        
        % timelock
        cfg                 = [];
        cfg.keeptrials      = 'yes';
        cfg.feedback        = 'none';
        data                = ft_timelockanalysis(cfg, data);
        data                = rmfield(data, 'cfg');
        
        % save this file
        savefast(sprintf('%s/P%02d-S%d_%s.mat', ...
            subjectdata.lockdir, sj, session, locking(l).name), ...
            'data');
    end

end

fprintf('DONE P%02d \n', sj);

end
