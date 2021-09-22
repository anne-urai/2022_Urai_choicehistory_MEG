function [data, blinksmp] = pupil_syncEyeMEG(cfg, data, trialdefinition, asc, replace, plotCheck)
% syncs eyetracking data to the MEG channels based on trigger info
disp('syncing MEG to EyeLink data');

% ==================================================================
% find the onset of first trial of this block in the MEG data
% ==================================================================

startMEG    = trialdefinition(find(trialdefinition(:, 16) == cfg.block, 1, 'first'), 1);
stopMEG     = trialdefinition(find(trialdefinition(:, 16) == cfg.block, 1, 'last'), 14) + 2*data.fsample;
assert((startMEG > 0), 'no valid startMEG'); assert(stopMEG > 0, 'no valid stopMEG');

% double check that we get those exact trials
startTrl    = trialdefinition(find(trialdefinition(:, 16) == cfg.block, 1, 'first'), 15);
stopTrl     = trialdefinition(find(trialdefinition(:, 16) == cfg.block, 1, 'last'), 15);
assert((startTrl > 0), 'no valid startTrl'); assert(stopTrl > 0, 'no valid stopTrl');

% corresponding EyeLink samples
startET     = str2double(regexp(asc.msg{find(~cellfun(@isempty, ...
    strfind(asc.msg, sprintf('trial%d_fix', startTrl))), 1, 'first')}, ...
    '\d*',  'match', 'once'));
stopET      = str2double(regexp(asc.msg{find(~cellfun(@isempty, ...
    strfind(asc.msg, sprintf('trial%d_feedback', stopTrl))), 1, 'last')}, ...
    '\d*',  'match', 'once')) + 2*asc.fsample;
assert((startET > 0), 'no valid startET'); assert(stopET > 0, 'no valid stopET');

% define the new time axis for the ET data that we want to be interpolated
eyedat.time{1}      = (asc.dat(1, find(asc.dat(1, :)==startET):find(asc.dat(1, :)==stopET)) ...
    - asc.dat(1, find(asc.dat(1, :)==startET))) ./ asc.fsample + data.time{1}(startMEG);
eyechans            = [2 3 4]; % horz vert pupil
eyedat.trial{1}     = asc.dat(eyechans, find(asc.dat(1, :)==startET):find(asc.dat(1, :)==stopET));
eyedat.label        = {'EYEH', 'EYEV', 'EYEPUPIL'};
eyedat.fsample      = data.fsample; % take MEG sampling rate

% ==================================================================
% perform the resampling
% ==================================================================

eyedat.trial{1}     = interp1(eyedat.time{1}', ...
    eyedat.trial{1}', data.time{1}(startMEG:stopMEG)', 'pchip', 0)';
eyedat.time{1}      = data.time{1}(startMEG:stopMEG); % use this new time axis

% ==================================================================
% parse blinks and saccades detected by EyeLink
% ==================================================================

blinktimes = cellfun(@regexp, asc.eblink, ...
    repmat({'\d*'}, length(asc.eblink), 1), repmat({'match'}, length(asc.eblink), 1), ...
    'UniformOutput', false); % parse blinktimes from ascdat
blinktimes2 = nan(length(blinktimes), 2);
for s = 1:length(blinktimes), a = blinktimes{s};
    for j = 1:2, blinktimes2(s, j) = str2double(a{j}); end
end

% remove blinksmp outside the range of the data
blinktimes2(sum((blinktimes2 < 0), 2) > 0, :) = [];
blinktimes2(sum((blinktimes2 > stopET), 2) > 0, :) = [];

% resample to the MEG sampling rate
blinksmp   = round((blinktimes2 - startET) * (data.fsample/asc.fsample));

% SACCADES
sacctimes = cellfun(@regexp, asc.esacc, ...
    repmat({'\d*'}, length(asc.esacc), 1), repmat({'match'}, length(asc.esacc), 1), ...
    'UniformOutput', false); % parse blinktimes from ascdat
sacctimes2 = nan(length(sacctimes), 2);
for s = 1:length(sacctimes), a = sacctimes{s};
    for j = 1:2,
        if str2double(a{j}) ~= 0,
            sacctimes2(s, j) = str2double(a{j});
        else
            sacctimes2(s, j) = str2double(a{j+1});
        end
    end
end

% remove saccsmp outside the range of the data
sacctimes2(sum((sacctimes2 < 0), 2) > 0, :) = [];
sacctimes2(sum((sacctimes2 > stopET), 2) > 0, :) = [];

% resample to the MEG sampling rate
saccsmp   = round((sacctimes2 - startET) * (data.fsample/asc.fsample));

% ==================================================================
% PREPROCESS PUPIL
% ==================================================================

if ~replace,    
    % take out only those data we want filtered and preprocessed
    % put the eye data from asc into the MEG chans
    eyedat.trial{1}(1, :) = data.trial{1}(find(~cellfun(@isempty, strfind(data.label, 'EYEH'))), startMEG:stopMEG);
    eyedat.trial{1}(2, :) = data.trial{1}(find(~cellfun(@isempty, strfind(data.label, 'EYEV'))), startMEG:stopMEG);
    eyedat.trial{1}(3, :) = data.trial{1}(find(~cellfun(@isempty, strfind(data.label, 'EYEPUPIL'))), startMEG:stopMEG);
end

% interpolate blinks
clf;
newpupil    = blink_interpolate(eyedat, blinksmp, 1);
print(gcf, '-dpdf', sprintf('~/Data/MEG-PL/PreprocFigs/P%02d-S%d_rec%d_b%d_blinkinterpolate.pdf', ...
    cfg.sj, cfg.session, cfg.rec, cfg.block));
% eyedat.trial{1}(find(strcmp(lower(eyedat.label), 'eyepupil')==1), :) = newpupil;

% regress out the response to blinks - also includes filtering.
% dont put back slow drift.
clf;
newpupil   = blink_regressout(newpupil, eyedat.fsample, blinksmp, saccsmp, 1, 0);
print(gcf, '-dpdf', sprintf('~/Data/MEG-PL/PreprocFigs/P%02d-S%d_rec%d_b%d_blinkregress.pdf', ...
    cfg.sj, cfg.session, cfg.rec, cfg.block));
% eyedat.trial{1}(find(strcmp(lower(eyedat.label), 'eyepupil')==1), :) = newpupil;

% ==================================================================
% normalize across the block
% ==================================================================

normalise = @(x) (x - mean(x)) ./ std(x);
newpupil = normalise(newpupil);

% ==================================================================
% put the clean timecourse back
% ==================================================================

data.trial{1}(find(~cellfun(@isempty, strfind(lower(data.label), 'eyeh'))), startMEG:stopMEG) = eyedat.trial{1}(1, :);
data.trial{1}(find(~cellfun(@isempty, strfind(lower(data.label), 'eyev'))), startMEG:stopMEG) = eyedat.trial{1}(2, :);
data.trial{1}(find(~cellfun(@isempty, strfind(lower(data.label), 'eyepupil'))), startMEG:stopMEG) = newpupil;

% ========================================================================
% see how the alignment did wrt the EOG chans, blinks should be aligned
% =======================================================================

if plotCheck,
    clf;
    for sp = 1:4,
        subplot(4,1,sp);
        %
        %         hold on;
        %         for b  = 1:length(blinksmp),
        %             plot([data.time{1}(blinksmp(b, 1)) data.time{1}(blinksmp(b, 1))], [-3 3], 'k');
        %             plot([data.time{1}(blinksmp(b, 2)) data.time{1}(blinksmp(b, 2))], [-3 3], 'g');
        %         end
        
        plot(data.time{1}(startMEG:stopMEG), ...
            (data.trial{1}(find(~cellfun(@isempty, strfind(data.label, 'EYEPUPIL'))), startMEG:stopMEG)), ...
            data.time{1}(startMEG:stopMEG), ...
            zscore(data.trial{1}(find(~cellfun(@isempty, strfind(data.label, 'EOGV'))), startMEG:stopMEG)));
        axis tight; % ylim([-3 3]);
        
        % define range
        xlimrange = linspace(data.time{1}(startMEG), data.time{1}(stopMEG),5);
        xlim([xlimrange(sp) xlimrange(sp+1)]);
        
        if sp == 1, title(sprintf('P%02d-S%d_rec%d_b%d', cfg.sj, cfg.session, cfg.rec, cfg.block), 'interpreter', 'none'); end
        if sp == 4, xlabel('Time (s)'); end
    end
    print(gcf, '-dpdf', sprintf('~/Data/MEG-PL/PreprocFigs/P%02d-S%d_rec%d_b%d_syncEL.pdf', cfg.sj, cfg.session, cfg.rec, cfg.block));
end
