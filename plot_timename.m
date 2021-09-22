function plot_timename(timename, fsample, xstep, ax)

if ~exist('xstep', 'var'); xstep = 0.5; end
if ~exist('ax', 'var'), ax = gca; end

% plot lines to indicate events
hold on; ylims = get(ax, 'ylim');

xticks = find(abs(timename) <  1./fsample); % black event onsets
xticks(diff(xticks) < 10) = [];
eventChange = find(diff(timename) < 0);

% white separation
for z = 1:length(eventChange), plot([eventChange(z) eventChange(z)], ylims, ...
        'w', 'linewidth', 3); end
% show event onsets
for z = 1:length(xticks), 
  %  plot([xticks(z) xticks(z)], ylims, 'k', 'linewidth', 0.5, 'linestyle', ':'); 
end

% put xticks at every 500  ms
xticks = find(mod(round(timename, 2), xstep) == 0);
xticks(diff(xticks) < 2) = []; % remove duplicates
for i = 1:length(eventChange),
    xticks(find(abs(xticks - eventChange(i)) < 4)) = NaN;
end
xticks(isnan(xticks)) = []; % remove numbers at event change points
xlab = arrayfun(@num2str, round(timename(xticks), 2), 'UniformOutput', false);
set(ax, 'xtick', xticks, 'xticklabel', xlab, ...
    'tickdir', 'out', 'xminortick', 'off');

end