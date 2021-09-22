function [runMe] =  motionEnergy_filtering(sj, session)
% run the motion energy filtering
% for MEG data, already upsample and append to MEG data
% for behavioural data, save per block (can check and process later)
% afterwards, can take DotCoord off cluster

if ~isdeployed,
    addpath(genpath('~/code/MEG'));
    addpath(genpath('~/code/Tools'));
    addpath('~/Documents/fieldtrip');
    ft_defaults;

    % this is where the filtering functions live
    addpath('~/code/motionEnergy');
    addpath('~/Dropbox/code/motionEnergy');
end

% for running on stopos
if ischar(sj), sj           = str2double(sj); end
if ischar(session), session = str2double(session); end

% ==================================================================
% LOAD IN SUBJECT SPECIFICS AND READ DATA
% ==================================================================

subjectdata = subjectspecifics(sj);
system(sprintf('touch %s/P%02d-S%d_A2started.log', subjectdata.preprocdir, sj, session));
fprintf('starting sj %d, session %d \n', sj, session);

% find behavioural files
behavFiles = dir(sprintf('%s/P%d_s%d_20*.mat', subjectdata.behavdir, sj, session));
% if we don't have one full file, find the block-specific ones
if length(behavFiles) ~= 1,
    behavFiles = dir(sprintf('%s/P%d_s%d_b*_20*.mat', subjectdata.behavdir, sj, session));
    % sort by creation date
    [~,idx]     = sort([behavFiles.datenum]);
    behavFiles  = behavFiles(idx);
end
disp({behavFiles(:).name}');

for f = 1:length(behavFiles),
    load(sprintf('%s/%s',  subjectdata.behavdir, behavFiles(f).name));

    % avoid window UI error
    display.dist        = window.dist;
    display.res         = window.res;
    display.width       = window.width;
    display.frameRate   = window.frameRate;
    display.center      = window.center;
    display.ppd         = deg2pix(display, 1);

    % WHICH BLOCKS ARE IN THIS FILE?
    blocks = find(~isnan(nanmean(results.response, 2)));
    for block = blocks',

        % ==================================================================
        % BUILD THE TRL MATRIX
        % ==================================================================

        clear mdat;
        ntrials = setup.ntrials;
        for t = 1:ntrials,
            try
                switch results.press{block, t}.buttonID,
                    case 'right'
                        results.respkey(t) = 18;
                    case 'left'
                        results.respkey(t) = 12;
                    otherwise
                        results.respkey(t) = NaN;
                end
            catch
                results.respkey(t) = NaN;
            end
        end

        %     fixoffset refoffset ...
        %     intervaloffset
        %     stimtype
        %     stimoffset ...
        %     respbutton resptype respcorrect
        %     respoffset
        %     feedbacktype
        %     feedbackoffset ...
        %     thistrlcnt blockcnt cfg.session
        %     add RT for writing the csv later

        % for the training sessions, feedbackoffset = respoffset
        % no pupil rebound time

        % build the matrix
        trl = [zeros(ntrials, 1) setup.fixtime(block, :)' ...
            setup.fixtime(block, :)' + ones(ntrials, 1)*setup.viewingtime...
            setup.increment(block, :)'...
            setup.fixtime(block, :)' + ones(ntrials, 1)*setup.viewingtime + setup.intervaltime(block, :)'...
            results.respkey' results.response(block, :)' results.correct(block, :)' ...
            setup.fixtime(block, :)' + ones(ntrials, 1)*setup.viewingtime + setup.intervaltime(block, :)' + ...
            ones(ntrials, 1)*setup.viewingtime + results.RT(block, :)'...
            results.correct(block, :)', ...
            setup.fixtime(block, :)' + ones(ntrials, 1)*setup.viewingtime + setup.intervaltime(block, :)' + ...
            ones(ntrials, 1)*setup.viewingtime + results.RT(block, :)' ...
            transpose(1:ntrials), block*ones(ntrials, 1) session*ones(ntrials, 1) ...
            results.RT(block, :)'];

        % resample from seconds to samples of frameRate
        samplerows = [1 2 3 5 9 11];
        trl(:, samplerows) = round(trl(:, samplerows) * (display.frameRate/1));

        % save this structure
        mdat.trialinfo  = trl;
        mdat.fsample    = display.frameRate;

        % block ordering
        if strcmp(behavFiles(f).name, 'P52_s3_b3_2015-07-23_15-18-25.mat') && block == 12,
            trl(:, 13) = 1;
        elseif strcmp(behavFiles(f).name, 'P52_s3_b3_2015-07-23_15-18-25.mat') && block == 13,
            trl(:, 13) = 2;
        end

        % ================================================ %
        % FIND CORRESPONDING DOTS FILE
        % ================================================ %

        usr = getenv('USER');
        switch usr
            case 'aeurai' % cartesius/lisa
                dotsdir = sprintf('/projects/0/neurodec/home/aurai/Data/MEG-PL/P%02d/DotCoord', sj);
            case 'anne' % macbook pro
                dotsdir = subjectdata.dotsdir;
        end

        % find the file
        dotsfile = dir(sprintf('%s/Dots_P%d_s%d_b%d_*.mat', dotsdir, sj, session, block));

        % exception for one sj
        if strcmp(behavFiles(f).name, 'P52_s3_b3_2015-07-23_15-18-25.mat') && block == 12,
            dotsfile = dir(sprintf('%s/Dots_P%d_s%d_b%d_*.mat', dotsdir, sj, session, 1));
        elseif strcmp(behavFiles(f).name, 'P52_s3_b3_2015-07-23_15-18-25.mat') && block == 13,
            dotsfile = dir(sprintf('%s/Dots_P%d_s%d_b%d_*.mat', dotsdir, sj, session, 2));
        %elseif sj == 3 && session == 3,
         %  assert(1==0)
            %if strcmp(behavFiles(f).name, 'P3_s3_b15_2014-05-21_16-03-35.mat'),
                % block 13-15
            %elseif 
                
        end

        % if there are several dotsfiles with the same block nr...
        if length(dotsfile) > 1,
            rightfile = find([dotsfile(:).datenum] < behavFiles(f).datenum);
            % if there are several, pick the one thats closest in time
            if length(rightfile) > 1,
                [~, rightfile] = min(abs([dotsfile(:).datenum] - behavFiles(f).datenum));
            end
            dotsfile = dotsfile(rightfile);
        end
        fprintf('%s/%s \n', dotsdir, dotsfile.name);

        % if this doesnt exist, only take the trialinfo and save
        if isempty(dotsfile),
            % STILL SAVE THE BEHAVIOURAL INFO
            savefast(sprintf('%s/motionE_P%d_s%d_b%d_2016.mat', ...
                subjectdata.dotsdir, sj, session, block), 'mdat');
            disp('NO DOTSFILE FOUND');
            continue;
        end

        % SKIP IF THIS ONE HAS ALREADY BEEN FILTERED
        resultsFile = sprintf('%s/%s', ...
            subjectdata.dotsdir, regexprep(dotsfile.name, 'Dots_', 'motionE_'));
        if exist(resultsFile, 'file'),
            fprintf('SKIPPING %s/%s, ALREADY EXISTS \n', ...
            subjectdata.dotsdir, regexprep(dotsfile.name, 'Dots_', 'motionE_'));
            continue;
        end

        % ==================================================================
        % DO ACTUAL FILTERING
        % ==================================================================
        
        try
            load(sprintf('%s/%s', dotsdir, dotsfile.name));
        catch
            disp('could not load');
            fprintf(' DELETING %s/%s \N', dotsdir, dotsfile.name);
            delete(sprintf('%s/%s', dotsdir, dotsfile.name));
        end

        % make sure the framerate matches the nr of dot frames
        assert(abs(0.75 - size(coord.ref, 3) / window.frameRate) < 0.02, ...
            'frameRate in dots and behav does not match!');

        % temporal range of the filter
        cfg            = [];
        cfg.frameRate  = display.frameRate;
        cfg.ppd        = display.ppd;

        % k = 60, from Kiani et al. 2008
        cfg.k = 60;

        % adjust spatial filters to match the speed in the dots
        effectiveSpeed = pix2deg(display, dots.speed) ./ dots.nvar;

        % Kiani et al. 2008 has a speed of 2.84 deg/s and used sigma_c and sigma_g
        % as 0.35 (not explicitly mentioned in their paper). To optimally scale the
        % filters for the speed in our dots, multiply the spatial parameters
        % see email exchange with Klaus Wimmer
        cfg.sigma_c = 0.35 * (effectiveSpeed / 2.84);
        cfg.sigma_g = 0.35 * (effectiveSpeed / 2.84);

        % equations exactly as in Kiani et al. 2008
        [f1, f2] = makeSpatialFilters(cfg);
        [g1, g2] = makeTemporalFilters(cfg);

        % ==================================================================
        % LOOP OVER TRIALS
        % ==================================================================

        for t = 1:setup.ntrials,

            % RT in number of frames
            RT = round(trl(t, 9)-trl(t, 5)-0.75*display.frameRate);
            if RT < 2, RT = 2; end % avoid error on very short RTs

            % append all coordinates until buttonpress
            thiscoord = cat(1, squeeze(coord.fix(1, t, 1:min([trl(t,2)-trl(t,1), size(coord.fix, 3)]), :, :)), ...
                squeeze(coord.ref(1, t, :, :, :)), ...
                squeeze(coord.interval(1, t, 1:min([trl(t,5)-trl(t,3), size(coord.interval, 3)]), :, :)), ...
                squeeze(coord.stim(1, t, :, :, :)), ...
                squeeze(coord.resp(1, t, 1:min([RT, size(coord.resp, 3)]), :, :)));

            % much quicker for testing
            % thiscoord = cat(1, ...
            %    squeeze(coord.interval(1, t, 1:min([trl(t,5)-trl(t,3), size(coord.interval, 3)]), :, :)), ...
            %    squeeze(coord.stim(1, t, :, :, :)));

            % check that we have no NaNs left
            assert(~any(isnan(thiscoord(:))));
            % change coordinates to movie
            thisstim = coord2stim(display, thiscoord, -dots.direction);
            % save2gif(thisstim); % show the movie

            % filters
            motionenergy = applyFilters(thisstim, f1, f2, g1, g2);

            % time axis
            mdat.time{t} = 0 : 1/display.frameRate : (size(motionenergy, 3) - 1)/display.frameRate;
            assert(numel(mdat.time{t}) == size(thisstim, 3));

            % save 4 quadrant, first is direction of dots
            switch dots.direction
                case 45
                    qs = {'southeast', 'southwest', 'northwest', 'northeast'};
                case 135
                    qs = {'southwest', 'northwest', 'northeast', 'southeast'};
                case 225
                    qs = {'northwest', 'northeast', 'southeast', 'southwest'};
                case 315
                    qs = {'northeast', 'southeast', 'southwest', 'northwest'};
                otherwise
                    error('could not determine direction of the dots');
            end
            cfg.targetDir = qs{1}; % save this in the results

            qsname = {'north', 'east', 'south', 'west'};
            for q = 1:4,
                % for each sample, take only one quadrant
                for s = 1:size(motionenergy, 3),
                    thisme = motionenergy(:, :, s);
                    mdat.trial{t}(q, s) = squeeze(sum(sum( ...
                        quadrant(thisme, qsname{q}))));
                end

                % also save the right label
                labelidx = sprintf('motionenergy_%s', qs{q});
                mdat.label{q} = labelidx;
            end

            % also save all the energy summed across space
            mdat.trial{t}(q+1, :) = squeeze(sum(sum(motionenergy)));
            mdat.label{q+1}       = 'all';
            % plot(mdat.time{t}, mdat.trial{t}); legend(mdat.label);
        end

        % save this block
        save(resultsFile, 'mdat', 'cfg');
    end % blocks
end % behavioural files

end
