function [substill2do] =  motionEnergy_collect(subjects)
% run the motion energy filtering
% for MEG data, already upsample and append to MEG data
% for behavioural data, save per block (can check and process later)
% afterwards, can take DotCoord off cluster

if ~isdeployed,
    addpath(genpath('~/code/MEG'));
    addpath(genpath('~/code/Tools'));
    addpath('~/Documents/fieldtrip');
    ft_defaults;
    warning off;
    
    % this is where the filtering functions live
    addpath('~/code/motionEnergy');
    addpath('~/Dropbox/code/motionEnergy');
end

substill2do = [];
if ~exist('subjects', 'var'),
    subjectdata = subjectspecifics('GAall');
    subjects    = subjectdata.all;
    subjects(ismember(subjects, [11 37])) = [];
end
if ischar(subjects), subjects = str2double(subjects);
end
close all; set(groot, 'defaultaxesfontsize', 6);

for sj = subjects,
    cnt = 1;
    close all; clearvars -except sj substill2do cnt subjects;
    subjectdata = subjectspecifics(sj);
    
    % ==================================================================
    % APPEND ALL FILES PER SESSION
    % ==================================================================
    
    clf;
    for session = 1:5,
        files = dir(sprintf('%s/motionE_P%d_s%d_*.mat', subjectdata.dotsdir, sj, session));
        
        % sort by the date and time the dots were saved
        try
            recdate     = regexp({files(:).name}, '201[0-9-_]*', 'match')';
            recdate     = cellfun(@datenum, recdate, repmat({'yyyy-mm-dd_HH-MM-SS'}, size(recdate)));
            [~, idx]    = sort(recdate);
        catch % if there are no dates & times in the filename, sort by block nr
            bnum        = regexp({files(:).name}, '(?<=b)\d*', 'match')';
            getOut      = @(x) x{1}; bnum        = cellfun(getOut, bnum, 'un', 0);
            bnum        = cellfun(@str2num, bnum);
            [~, idx]    = sort(bnum);
        end
        files         = files(idx);
        
        if ismember(session, [1 5]),
            assert(length(files) <= 10, 'too many dotfiles!');
        elseif ismember(session, [2 3 4]),
            assert(length(files) <= 15, 'too many dotfiles!');
        end
        
        % append across all filtered motion
        clear inputfiles
        for f = 1:length(files),
            
            % get this file's motion energy
            fprintf('loading file %s/%s \n', ...
                subjectdata.dotsdir, files(f).name);
            load(sprintf('%s/%s', ...
                subjectdata.dotsdir, files(f).name));
            mdat.trialinfo(:, end+1) = sj;
            if isfield(mdat, 'label'),
                % skip if this label can't be found
                mdat.label{end}   = 'motionenergy_combined'; % otherwise, fieldtrip will remove the rest
            else
                % if there is just behav data, no filtered coords
                for t = 1:size(mdat.trialinfo, 1),
                    trlLength       = min([mdat.trialinfo(t, 9) mdat.trialinfo(t, 5) + round(3.75 * mdat.fsample)]); % RT, in samples
                    mdat.time{t}    = 0 : 1/mdat.fsample : (trlLength - 1)/mdat.fsample;
                    mdat.trial{t}   = nan(5, trlLength);
                end
                mdat.label = {'motionenergy_southeast', 'motionenergy_southwest', ...
                    'motionenergy_northwest', 'motionenergy_northeast', 'motionenergy_combined'};
                cfg.targetDir = NaN;
            end
            
            % also get the actual coherence and some other variables
            behavFiles = dir(sprintf('/projects/0/neurodec/Data/MEG-PL/P%02d/Behav/P%d_s%d_*.mat', sj, sj, session));
            foundRightFile = 0;
            
            if numel(behavFiles) == 1,
                foundRightFile = 1;
                load(sprintf('/projects/0/neurodec/Data/MEG-PL/P%02d/Behav/%s', sj, behavFiles.name));
            else
                % make sure to find the right file to get window settings...
                for b = 1:numel(behavFiles),
                    load(sprintf('/projects/0/neurodec/Data/MEG-PL/P%02d/Behav/%s', sj, behavFiles(b).name));
                    try
                        if isequaln(results.response(unique(mdat.trialinfo(:, 13)), :), ...
                                mdat.trialinfo(:, 7)') && ...
                                isequaln(setup.increment(unique(mdat.trialinfo(:, 13)), :), ...
                                mdat.trialinfo(:, 4)'),
                            foundRightFile = 1;
                            break; % use this one
                        end
                    end
                end
            end
            assert(foundRightFile == 1, 'could not find the corresponding behavfile');
            
            display.dist        = window.dist;
            display.res         = window.res;
            display.width       = window.width;
            display.frameRate   = window.frameRate;
            display.center      = window.center;
            display.ppd         = deg2pix(display, 1);
            
            % save the target direction of each participant
            for t = mdat.trialinfo(:, 12)',
                mdat.trialinfo(t, 17) = dots.coherence(mdat.trialinfo(t, 13), t);
            end
            assert(mean(unique(mdat.trialinfo(:, 17))) == 0.7);
            
            if ~isnan(cfg.targetDir),
                mdat.trialinfo(:, 18) = ~isempty(strfind(mdat.label, cfg.targetDir));
            else
                mdat.trialinfo(:, 18) = NaN;
            end
            inputfiles{f}     = mdat;
            
        end
        
        if ~exist('inputfiles', 'var'), continue; end
        inputfiles  = inputfiles(find(cellfun(@isempty, inputfiles) == 0));
        if length(inputfiles) == 1,
            data        = inputfiles{1};
        else
            data        = ft_appenddata([], inputfiles{:});
        end
        
        % ==================================================================
        % RESAMPLE TO 60 HZ
        % ==================================================================
        
        cfg             = [];
        cfg.resamplefs  = 60;
        
        % only do this if necessary
        if abs(cfg.resamplefs - data.fsample) > 2,
            
            samplerows      = [1 2 3 5 9 11];
            data.trialinfo(:,samplerows) = round(data.trialinfo(:,samplerows) * (cfg.resamplefs / data.fsample));
            cfg.feedback    = 'no';
            tic;    data = ft_resampledata(cfg, data); toc;
        end
        
        % ==================================================================
        % PLOT SANITY CHECK
        % ==================================================================
        
        % remove noresp trials
        cfg                 = [];
        cfg.trials          = find(~isnan(data.trialinfo(:, 8)));
        data                = ft_selectdata(cfg, data);
        
        cfg                 = [];
        cfg.channel         = 'motionenergy_combined';
        cfg.trials(1).name  = 'stronger';
        cfg.trials(1).idx   = find(data.trialinfo(:, 4) == 1 ...
            & data.trialinfo(:, 14) == session);
        cfg.trials(2).name  = 'weaker';
        cfg.trials(2).idx   = find(data.trialinfo(:, 4) == -1 ...
            & data.trialinfo(:, 14) == session);
        cfg.nofeedback      = true;
        cfg.noresp          = true;
        cfg.plotalltrials   = true;
        cfg.overlaymean     = true;
        
        subplot(3,4,cnt); cnt = cnt + 1;
        plotEventRelated(cfg, data);
        axis square;
        
        % ==================================================================
        % SCALAR FOR STIMULUS, 70 +- threshold % coherence
        % ==================================================================
        
        locking.offset       = data.trialinfo(:, 5) - data.trialinfo(:, 1);
        locking.prestim      = -0.2; % rise time of the filter
        locking.poststim     = 0.75;
        
        % redefine trials
        cfg                 = [];
        cfg.begsample       = round(locking.offset - locking.prestim * data.fsample); % take offset into account
        cfg.endsample       = round(locking.offset + locking.poststim * data.fsample);
        cfg.offset          = -locking.offset;
        ldata               = redefinetrial(cfg, data);
        ldata               = ft_timelockanalysis(struct('keeptrials', 'yes', 'vartrllength', 2), ldata);
        
        % what if the threshold changed between sessions?
        singletrial_motionenergy = squeeze(nanmean(ldata.trial(:, end, :), 3));
        
        subplot(3,4,cnt); cnt = cnt + 1;
        histogram(singletrial_motionenergy(data.trialinfo(:, 4) == 1), 'edgecolor', 'none');
        hold on;
        histogram(singletrial_motionenergy(data.trialinfo(:, 4) == -1), 'edgecolor', 'none');
        box off; axis tight;
        
        % check
        if ~all(isnan(singletrial_motionenergy)),
            roc = rocAnalysis(singletrial_motionenergy(data.trialinfo(:, 4) == -1), ...
                singletrial_motionenergy(data.trialinfo(:, 4) == 1), 0, 0);
            assert(roc.i > 0.85, 'motion energy does not separate stimulus types');
            title(sprintf('P%02d-S%d, n%d, b%d, roc %.3f', sj, session, ...
                size(data.trialinfo, 1), numel(unique(data.trialinfo(:, 13))), roc.i), 'fontsize', 6);
        end
        
        outputfile = sprintf('%s/P%02d-S%d_allmdat.mat', subjectdata.dotsdir, sj, session);
        savefast(outputfile, 'data');
        
    end
    print(gcf, '-dpdf', ...
        sprintf('%s/P%02d_motionenergy.pdf', subjectdata.figsdir, sj));
    
    %A2b_motionNormalise(sj);
end

% ==================================================================
% APPEND ALL
% ==================================================================

if length(subjects) > 1,
    % get all the singletrial values
    subjectdata     = subjectspecifics('GAall');
    
    % this doesn't work, since the sampling rates are different....
    cfg             = [];
    cd(subjectdata.path);
    cfg.inputfile   = rdir('P*/DotCoord/P*-S*_allmdat.mat'); % matlab's dir cant descend in subdirs
    data = ft_appenddata(cfg);
    data = rmfield(data, {'cfg'}); % save ram
    savefast(sprintf('%s/GrandAverage/motionEnergy/GA_allmdat.mat', subjectdata.path), 'data');
end

disp('DONE');

% ==================================================================
% WRITE 2 CSV
% ==================================================================

clearvars -except subjectdata
subjectdata = subjectspecifics('ga');
load(sprintf('%s/GrandAverage/motionEnergy/GA_allmdat.mat', subjectdata.path));

t = array2table(data.trialinfo(:, [4 7 15 12 13 14 16]), ...
    'variablenames', {'stimulus', 'response', 'rt', 'trial', 'block', 'session', 'subj_idx'});

t.prevresp = circshift(t.response, 1);
t.prevstim = circshift(t.stimulus, 1);

t.prev2resp = circshift(t.response, 2);
t.prev2stim = circshift(t.stimulus, 2);
t.prev3resp = circshift(t.response, 3);
t.prev3stim = circshift(t.stimulus, 3);

% sort so that findgroups returns the right order
t = sortrows(t, {'subj_idx', 'session', 'block'});

% zscore RT per block
normalize  = @(x) {(x - nanmean(x)) ./ nanstd(x)};
assert(all(~isinf(abs(log(t.rt)))), 'zero RTs');
rtnorm     = splitapply(normalize, log(t.rt), ...
    findgroups(t.subj_idx, t.session, t.block));
rtnorm     = cat(1, rtnorm{:});
t.prevrt   = circshift(rtnorm, 1); % use this normalized version
t.prev2rt   = circshift(rtnorm, 2); % use this normalized version
t.prev3rt   = circshift(rtnorm, 3); % use this normalized version

% dont use previous trials that are not continuous
wrongTrls   = ([NaN; diff(t.trial)] ~= 1);
t(wrongTrls, :) = []; % remove those trials alltogether, don't know how HDDM handles missing values

% code response as [0,1]
t.response(t.response < 0) = 0;
writetable(t, sprintf('%s/CSV/2ifc_allsessions_motionenergy_hddm.csv', subjectdata.path));

end
