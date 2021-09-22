
function [b, legtxt, ylabl, activity] = plotData(data, t, what2plot)
% ==================================================================
% takes the data and the type of stimuli that should be plotted, and plots
% them - add uncorrected statistics
% ==================================================================

% ==================================================================
% TAKE SUBSET
% ==================================================================

if isfield(what2plot, 'subset') && ~isempty(what2plot.subset),
    t = t(t.(what2plot.subset{1}) == what2plot.subset{2}, :);
end

% ==================================================================
% LINK TABLE TO MEG IDX
% ==================================================================

% map table idx to MEG idx
[~, ~, tidx]    = intersect(data.trialinfo(:, 18), t.idx);
t               = t(tidx, :); % keep only that part of the table

% and make sure we only take those that match
[~, ~, tidx]    = intersect(t.idx, data.trialinfo(:, 18));
data.avg        = data.avg(tidx, :);
data.trialinfo  = data.trialinfo(tidx, :);

% some checks
assert(isequal(data.trialinfo(:, 4), t.stim), 'stimuli not matched');
assert(isequal(data.trialinfo(:, 7), t.resp), 'responses not matched');

% ==================================================================
% CREATE CONTRAST
% ==================================================================

switch length(what2plot.contrast)
    case 1
        [t.contrast, names] = findgroups(t.(what2plot.contrast{1}));
        legtxt = {};
        for j = 1:numel(unique(names)),
            legtxt{j} = sprintf('%s %d', what2plot.contrast{1}, names(j));
        end
    case 2
        [t.contrast, names1, names2] = findgroups(t.(what2plot.contrast{1}), ...
            t.(what2plot.contrast{2}));
        legtxt = {};
        for j = 1:numel(unique(names1)),
            for k = 1:numel(unique(names2)),
                legtxt{end+1} = sprintf('%s %d, %s %d', ...
                    what2plot.contrast{1}, names1(length(legtxt)+1), ...
                    what2plot.contrast{2}, names2(length(legtxt)+1));
            end
        end
        
    case 3
        [t.contrast, names1, names2, names3] = findgroups(t.(what2plot.contrast{1}), ...
            t.(what2plot.contrast{2}), t.(what2plot.contrast{3}));
        legtxt = {};
        for j = 1:numel(unique(names1)),
            for k = 1:numel(unique(names2)),
                for m = 1:numel(unique(names3)),
                    legtxt{end+1} = sprintf('%s %d, %s %d, %s %d', ...
                        what2plot.contrast{1}, names1(length(legtxt)+1), ...
                        what2plot.contrast{2}, names2(length(legtxt)+1), ...
                        what2plot.contrast{3}, names3(length(legtxt)+1));
                end
            end
        end
        
end
[g, tid1, tid2] = findgroups(t.subjnr, t.contrast);

% ==================================================================
% create new table with averages, one for each subject and contrast
% ==================================================================

meanFun         = @(x) trimmean(x, 99, 'round', 1); % more robust to outliers?
meanFun         = @(x) nanmean(x, 1); % make sure we average over the 1st dimension

% splitapply can't deal with NaNs in g when the input is 2D...
data.avg(isnan(g), :)       = [];
data.trialinfo(isnan(g), :) = [];
t(isnan(g), :)              = [];
g(isnan(g))                 = [];

% compute the averages per contrast
activity        = table(tid1, tid2, splitapply(meanFun, data.avg, g), ...
    'variablenames', {'subjnr', 'contrast', 'avg'});
activity.medRT  = splitapply(@median, t.rt, g);

% keep the original contrasts in
for j = 1:length(what2plot.contrast),
    activity.(what2plot.contrast{j}) = splitapply(@unique, t.(what2plot.contrast{j}), g);
end

% ==================================================================
% CREATE DIFFERENCE
% ==================================================================

if isfield(what2plot, 'difference') && ~isempty(what2plot.difference),
    avgRow = strcmp(what2plot.contrast, what2plot.difference{1});
    assert(sum(avgRow) == 1, 'difference must be 1 of the contrast variables');
    
    % take the difference
    [dg, ynames]   = findgroups(activity.(what2plot.difference{1}));
    difference.avg = activity.avg(dg == 2, :) - activity.avg(dg == 1, :);
    
    % fill in the rest of the variables
    vars = activity.Properties.VariableNames;
    for v = 1:length(vars),
        % skip some variables that wont match
        if ~strcmp(vars{v}, {'avg', 'contrast', 'medRT', what2plot.difference{1}}),
            assert(isequal( activity.(vars{v})(dg == 1, :), ...
                activity.(vars{v})(dg == 2, :)), 'difference does not match');
            difference.(vars{v}) = activity.(vars{v})(dg == 1, :);
        end
    end
    difference.contrast = activity.contrast(dg == 1, :);
    difference.medRT    = mean([activity.medRT(dg == 1, :), activity.medRT(dg == 2, :)], 2);
    activity            = difference;
    
    ylabl = {sprintf('%s %d vs.', what2plot.difference{1}, ynames(1)), ...
        sprintf('%s %d', what2plot.difference{1}, ynames(2))};
    
    % generate legend
    legtxt = {};     % also change the legend
    switch sum(avgRow == 0)
        case 1
            names = unique(difference.(what2plot.contrast{avgRow == 0}));
            for j = 1:numel(names),
                legtxt{j} = sprintf('%s %d', what2plot.contrast{avgRow == 0}, names(j));
            end
        case 2
            conds = setdiff(what2plot.contrast, what2plot.difference);
            for c = 1:length(conds),
                vals(:, c) = splitapply(@unique, activity.(conds{c}), findgroups(activity.contrast));
            end
            for i = 1:size(vals, 1),
                legtxt{end+1} = sprintf('%s %d, %s %d', ...
                    conds{1}, vals(i, 1), conds{2}, vals(i, 2));
            end
    end
    
else
    ylabl = [];
end

% ==================================================================
% AVERAGE TOGETHER AFTER TAKING THE DIFFERENCE
% ==================================================================

if isfield(what2plot, 'average') && ~isempty(what2plot.average),
    avgRow = strcmp(what2plot.contrast, what2plot.average{1});
    assert(sum(avgRow) == 1, 'average must be 1 of the contrast variables');
    
    % take the difference
    [dg, ynames]   = findgroups(activity.(what2plot.average{1}));
    difference.avg = (activity.avg(dg == 2, :) + activity.avg(dg == 1, :)) ./ 2;
    
    difference.contrast = activity.contrast(dg == 1, :);
    difference.medRT    = mean([activity.medRT(dg == 1, :), activity.medRT(dg == 2, :)], 2);
    
    assert(all(difference.subjnr(dg ==2 ) == difference.subjnr(dg == 1)), 'subjnrs must match')
    difference.subjnr = difference.subjnr(dg == 1);
    try difference.repeat = difference.repeat(dg == 1); end
    try difference.session = difference.session(dg == 1); end
    try difference.prev_resp = difference.prev_resp(dg == 1); end

    activity = difference;
    % keep the correct legend names
    if numel(unique(activity.contrast)) > 1,
        conds = setdiff(what2plot.contrast, [what2plot.difference what2plot.average]);
        clear vals; clear legtxt;
        for c = 1:length(conds),
            vals(:, c) = splitapply(@unique, activity.(conds{c}), findgroups(activity.contrast));
        end
        for i = 1:size(vals, 1),
            legtxt{i} = sprintf('%s %d', conds{1}, vals(i));
        end
    else
        legtxt = []; ylabl = [];
    end
end

if isfield(what2plot, 'label') && ~isempty(what2plot.label), ...
        ylabl = what2plot.label; end

% ==================================================================
% PLOT
% ==================================================================

hold on;
plot([data.time(find(data.time >= 0, 1, 'first')) ...
    data.time(end)], [0 0], 'k', 'linewidth', 0.5);

% average over participants, not contrasts!
mn      = splitapply(@nanmean, activity.avg, findgroups(activity.contrast));
sem     = permute(  splitapply(@nanstd, activity.avg, findgroups(activity.contrast)) ...
    ./ sqrt(numel(unique(activity.subjnr))), [2 3 1]);
if ndims(sem) == 2, sem = sem'; end

colors  = viridis(size(mn, 1) + 2);
colors  = colors(2:end-1, :);

% colors  = cbrewer('div', 'RdBu', size(mn, 1));
b       = boundedline(1:size(data.avg, 2), mn, sem, 'nan', 'gap', 'cmap', colors);

% ==================================================================
% LAYOUT
% ==================================================================

axis tight; ylims = get(gca, 'ylim');
% for visual contrast
% if roundn(ylims(2), -2) == 0.4, ylims(2) = 0.2; end
ylim([min(get(gca, 'ylim')) ylims(2)]);
offsetAxes;
ylims = [min(get(gca, 'ytick')) ylims(2)];

% ticks
xticks = find(abs(data.timename) <  1./data.fsample); % black event onsets
xticks(diff(xticks) < 10) = [];
eventChange = find(diff(data.timename) < 0);
eventOnset = xticks; % show event onsets
for z = 1:length(eventOnset), plot([eventOnset(z) eventOnset(z)], ...
        ylims, 'k', 'linewidth', 0.5); end

% show ref and stimulus offset
offsettime = find(roundn(data.timename, -3) == 0.75);
plot([offsettime(1) offsettime(1)], ylims, 'color', [0.3 0.3 0.3], 'linewidth', 0.2);
plot([offsettime(2) offsettime(2)], ylims, 'color', [0.3 0.3 0.3], 'linewidth', 0.2);

% put xticks at every 500  ms
xticks = find(mod(round(data.timename, 3), 0.5) == 0);
xticks(diff(xticks) < 10) = []; % remove duplicates
for i = 1:length(eventChange),
    xticks(find(abs(xticks - eventChange(i)) < 4)) = NaN;
end
xticks(isnan(xticks)) = []; % remove numbers at event change points
xlab = arrayfun(@num2str, round(data.timename(xticks), 2), 'UniformOutput', false);
xlab(strcmp('0', xlab)) = {'ref', 'stim', 'resp', 'fb'};
set(gca, 'xtick', xticks, 'xticklabel', xlab, ...
    'tickdir', 'out', 'xminortick', 'off');

hold on;
mn = splitapply(@nanmedian, activity.medRT, findgroups(activity.contrast));
% show median RT for each of the categories
for n = 1:length(mn),
    x = eventOnset(2) + mn(n) * data.fsample;
    % plot([x x], ylims, 'color', colors(n, :), 'linestyle', ':');
end

% CAN I DO A FULL LINEAR MODEL SPECIFICATION ON THE TABLE HERE?
if numel(unique(activity.subjnr)) > 3,
    % add difference stats below!
    switch numel(unique(activity.contrast))
        case 1 % simple ttest against zero
            h = ttest(activity.avg(activity.contrast == 1, :), 0, 'alpha', 0.01);
            assert(size(h, 2) == size(activity.avg, 2), 'statmask not the right size');
            plot(find(h==1), min(get(gca, 'ylim'))*ones(size(find(h==1))), 'k.');
        case 2 % paired ttest between conditions
            h = ttest(activity.avg(activity.contrast == 1, :), ...
                activity.avg(activity.contrast == 2, :), 'alpha', 0.01);
            assert(size(h, 2) == size(activity.avg, 2), 'statmask not the right size');
            plot(find(h==1), min(get(gca, 'ylim'))*ones(size(find(h==1))), 'k.');
        otherwise
            % with 2 contrasts, what to test? interaction?
    end
end

% use ylabel to indicate difference metric
if isfield(what2plot, 'difference') ...
        && ~isempty(what2plot.difference),
    ylabel(ylabl, 'interpreter', 'none');
end

if exist('legtxt', 'var'),
    % rename legend to something more sensible
    if ~isempty(legtxt),
        legtxt = regexprep(legtxt, 'session 1', 'first session');
        legtxt = regexprep(legtxt, 'session 2', 'last session');
        legtxt = regexprep(legtxt, 'repeat 0', 'alternate');
        legtxt = regexprep(legtxt, 'repeat 1', 'repeat');
        legtxt = regexprep(legtxt, '-1', 'weaker');
        legtxt = regexprep(legtxt, '1', 'stronger');
    end
else
    legtxt = [];
end


end
