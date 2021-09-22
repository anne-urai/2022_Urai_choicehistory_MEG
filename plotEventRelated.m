function [newlockdata, newlocktime, bl] = plotEventRelated(allcfg, data)
% in case of timelocked data:
% channel: which channels, these will be averaged over
% trials: structure with the name and the idx of trials that will be
% separately plotted
%
% in case of frequency data:
% channel: which channels, these will be averaged over
% - TODO: if structure with two sets of names, take difference
% freq: frequencies, select y axis
% trials: structure with the name and the idx of trials, difference

% set some defaults

if ~isfield(allcfg, 'baselineCorrect'), allcfg.baselineCorrect = 0; end
assert(isnumeric(allcfg.baselineCorrect), 'baselineCorrect must be 0 or 1');
if ~isfield(allcfg, 'trials'); allcfg.trials(1).idx = 1:length(data.trial); allcfg.trials(1).name = 'all'; end

% select only the channels to plot
cfg             = [];
cfg.channel     = allcfg.channel;
data            = ft_selectdata(cfg, data);

% make 4 lockings: ref, stim, resp, fb
locking(1).offset       = data.trialinfo(:, 2) - data.trialinfo(:, 1);
locking(1).prestim      = 0.1;
locking(1).poststim     = 0.9;
locking(1).name         = 'ref';

locking(2).offset       = data.trialinfo(:, 5) - data.trialinfo(:, 1);
locking(2).prestim      = 0.1;
locking(2).poststim     = 0.75;
locking(2).name         = 'stim';

if ~allcfg.noresp,
  locking(3).offset       = data.trialinfo(:, 9) - data.trialinfo(:, 1);
  locking(3).prestim      = 0.2;
  locking(3).poststim     = 1.5;
  locking(3).name         = 'resp';
end

if ~allcfg.nofeedback, % for motion timecourses
    % stop at RT
    locking(4).offset       = data.trialinfo(:, 11) - data.trialinfo(:, 1);
    locking(4).prestim      = 0.5;
    locking(4).poststim     = 1.9;
    locking(4).name         = 'feedback';
else
    % stop at RT
    if ~allcfg.noresp,
      locking(3).poststim = -0.01;
    end
end

for l = 1:length(locking),

    disp(locking(l).name);

    % redefine trials
    cfg                 = [];
    cfg.begsample       = round(locking(l).offset - locking(l).prestim * data.fsample); % take offset into account
    cfg.endsample       = round(locking(l).offset + locking(l).poststim * data.fsample);
    cfg.offset          = -locking(l).offset;
    ldata               = redefinetrial(cfg, data);

    cfg                 = [];
    cfg.keeptrials      = 'yes';
    cfg.vartrllength    = 2;
    lockdata{l}         = ft_timelockanalysis(cfg, ldata);
end

% append all into one timecourse
if allcfg.noresp,
    newlockdata = cat(2, squeeze(lockdata{1}.trial), squeeze(lockdata{2}.trial));
    newlocktime = cat(2, squeeze(lockdata{1}.time), squeeze(lockdata{2}.time));
elseif allcfg.nofeedback,
    newlockdata = cat(2, squeeze(lockdata{1}.trial), squeeze(lockdata{2}.trial), ...
        squeeze(lockdata{3}.trial));
    newlocktime = cat(2, squeeze(lockdata{1}.time), squeeze(lockdata{2}.time), ...
        squeeze(lockdata{3}.time));
else
    newlockdata = cat(2, squeeze(lockdata{1}.trial), squeeze(lockdata{2}.trial), ...
        squeeze(lockdata{3}.trial), squeeze(lockdata{4}.trial));
    newlocktime = cat(2, squeeze(lockdata{1}.time), squeeze(lockdata{2}.time), ...
        squeeze(lockdata{3}.time), squeeze(lockdata{4}.time));
end

% correct baseline, pre-ref activity on each trial
if allcfg.baselineCorrect == 1,
    disp('baseline correcting');
    bl = mean(squeeze(lockdata{1}.trial(:, :, find(lockdata{1}.time < 0))), 2);
    newlockdata = bsxfun(@minus, newlockdata, bl);
elseif allcfg.baselineCorrect == 2,
    newlockdata = transpose(detrend(newlockdata', 'constant')); % demean
   % newlockdata = detrend(newlockdata', 'linear'); % detrend
else
    bl = nan(1, length(ldata.trial));
end

% make means and std per subset of trials
newtime = 1:size(newlockdata, 2);
newmean = []; newsem = []; newlegend = {};
for t = 1:length(allcfg.trials),
    newmean = [newmean ; nanmean(newlockdata(allcfg.trials(t).idx, :))];
    newsem = [newsem ; nanstd(newlockdata(allcfg.trials(t).idx, :)) ...
        ./ sqrt(length(allcfg.trials(t).idx))];
    newlegend = [newlegend allcfg.trials(t).name];
end

% plot with shaded errorbars
colors = linspecer(length(allcfg.trials), 'qualitative');
hold on;
if allcfg.plotalltrials,
    if length(allcfg.trials) == 1,
        % each line gets a different color
        plot(newtime, newlockdata(allcfg.trials(t).idx, :), 'linewidth', 0.5);
    else
        for t = 1:length(allcfg.trials),
            tmpp = plot(newtime, newlockdata(allcfg.trials(t).idx, :), 'color', colors(t,:));
            for tidx = 1:length(tmpp), tmpp(tidx).Color(4)  = 0.1; end
            p(t) = tmpp(1);
            newlegend = [newlegend allcfg.trials(t).name];
            if allcfg.overlaymean,
                plot(newtime, mean(newlockdata(allcfg.trials(t).idx, :)), 'k', 'linewidth', 1);
            end
        end
    end
else
    p = boundedline(newtime, newmean, permute(newsem, [2 1 3]));
end
axis tight;
% legend(p, newlegend, 'Location', 'EastOutside'); legend boxoff;

% layout
tp = 0;
xticks = []; xlabels = {};
cumultime = 0; hold on;
ylims = get(gca, 'ylim');
for l = 1:length(locking),
    xticks = [xticks dsearchn(lockdata{l}.time', tp)+cumultime];
    plot([xticks(end) xticks(end)], ylims, 'k', 'linewidth', 0.5); % black event onsets
    cumultime = cumultime + length(lockdata{l}.time);
    cmt(l) = cumultime;
    plot([cumultime cumultime], ylims, 'w', 'linewidth', 1);% white event separators
    xlabels = [xlabels locking(l).name];
end
set(gca, 'XTick', xticks, 'XTickLabel', xticks, 'tickdir', 'out');
box off;

end
