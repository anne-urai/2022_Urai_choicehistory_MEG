function [] = preproc_appendRecs(sj, sessions)
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

    clearvars -except sj session sessions subjectdata;
    inputfiles = {};

    for rec = subjectdata.session(session).recsorder,

         % load in this file
        load(sprintf('%s/P%02d-S%d_rec%d_cleandata.mat', ...
            subjectdata.preprocdir, sj, session, rec));
        fprintf('loading %s/P%02d-S%d_rec%d_cleandata.mat \n', ...
            subjectdata.preprocdir, sj, session, rec);

        % append data files...
        inputfiles{end+1} = data;

        % ... and grad structs
        if ~exist('gradstructs', 'var'),
            gradstructs = data.grad;
        else
            gradstructs(end+1) = data.grad;
        end

    end
        
    % append all together
    data = ft_appenddata([], inputfiles{:});
    
    % keep grad structure for planar gradient transformation
    % right now, cheat by taking the one from first recording

    data.grad_first     = inputfiles{1}.grad;
    data.grad_avg       = ft_average_sens(gradstructs);
    data.grad_all       = gradstructs;

    % use this for now
    data.grad           = data.grad_first;
    data                = rmfield(data, 'cfg');
    
    savefast(sprintf('%s/P%02d-S%d_cleandata.mat', ...
        subjectdata.preprocdir, sj, session), 'data');
    fprintf('SAVED %s/P%02d-S%d_cleandata.mat \n', ...
        subjectdata.preprocdir, sj, session);

end

fprintf('DONE P%02d \n', sj);

end
