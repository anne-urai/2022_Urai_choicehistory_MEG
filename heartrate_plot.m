function heartrate_plot

% ==================================================================
% PLOT THE OUTCOME OF HEARTRATE OVER SESSIONS
% ==================================================================

subjectdata = subjectspecifics('ga');
close all;
colors = cbrewer('qual', 'Set1', 9);
cols = colors([9 1 2], :);
hr = readtable(sprintf('%s/CSV/heartrate.csv', subjectdata.path));
hr = hr(ismember(hr.subjnr, subjectdata.clean), :);

% remove some unlikely outliers
hr = hr(hr.heartrate > 30, :);

% reshape
res = unstack(hr, 'heartrate', 'block');

% pre-pharma baseline from subjectdata csv file
res.bl1 = nan(size(res.subjnr)); % 3 hours before MEG, entry to institute
res.bl2 = nan(size(res.subjnr)); % 1.5 hours later, 1.5 hours before MEG

for sj = unique(res.subjnr)',
    sjdat = subjectspecifics(sj);
    for session = 1:length(sjdat.session),
        thishr = sjdat.session(session).heartrate;
        
        res.bl1(res.subjnr == sj & res.session == session) = thishr(1);
        res.bl2(res.subjnr == sj & res.session == session) = thishr(2);
    end
end

% plot
subplot(3,2,1); hold on;
drugs = {'placebo', 'atomoxetine', 'donepezil'};
for d = 1:length(drugs),
    
    % timecourse
    plot([-1 1:10], ...
        [res{contains(res.drug, drugs{d}), 'bl1'}, ...
        res{contains(res.drug, drugs{d}), contains(res.Properties.VariableNames, 'x')}], ...
     '-', 'color', [cols(d, :) 0.1]);
    % group average
    plot(1:10, nanmean(res{contains(res.drug, drugs{d}), contains(res.Properties.VariableNames, 'x')}), ...
     '.-', 'color', cols(d, :));
 
    % baseline points
    plot(-1, nanmean(res{contains(res.drug, drugs{d}), 'bl1'}), 'o', 'color', cols(d, :), 'markersize', 4);
   % plot(-1, nanmean(res{contains(res.drug, drugs{d}), 'bl2'}), 'o', 'color', cols(d, :), 'markersize', 4);

end

ylabel('Heart rate (bpm)');
set(gca, 'xtick', [-1 1 5.5 10], 'xticklabel', [-3 0 1 2]);
xlabel('Hours from MEG start');
xlim([-1.5, 10]);
offsetAxes; tightfig;
print(gcf, '-dpdf', sprintf('%s/Figures/heartrate_timecourse.pdf', subjectdata.path));

% =================================
% COMPUTE SOME STATS
% average per participant, so that we don't duplicate data for the 2
% sessions in stats
% =================================

res.avg_meg = nanmean(res{:, contains(res.Properties.VariableNames, 'x')}, 2);

[gr, tab] = findgroups(res(:, {'drug', 'subjnr'}));
[tab.avg_meg] = splitapply(@nanmean, res.avg_meg, gr);
[tab.bl1] = splitapply(@nanmean, res.bl1, gr);

[p,tbl,stats] = anova1(tab.bl1, findgroups(tab.drug), 'off');
fprintf('bl1: F(%d) = %.3f, p = %.4f \n', tbl{2,3}, tbl{2,5}, tbl{2,6});

[p,tbl,stats] = anova1(tab.avg_meg, (tab.drug), 'off');
fprintf('avg_meg: F(%d) = %.3f, p = %.4f \n', tbl{2,3}, tbl{2,5}, tbl{2,6});
 
% [c,m,h,gnames] = multcompare(stats, 'display', 'off');
% fprintf('placebo vs atomoxetine: F(%d) = %.3f, p = %.4f \n', tbl{2,3}, tbl{2,5}, tbl{2,6});

[h,p,ci,stats] = ttest2(tab{contains(tab.drug, 'placebo'), 'avg_meg'}, ...
    tab{contains(tab.drug, 'atomoxetine'), 'avg_meg'});
fprintf('placebo vs atomox: t(%d) = %.3f, p = %.4f \n', stats.df, stats.tstat, p);

[h,p,ci,stats] = ttest2(tab{contains(tab.drug, 'placebo'), 'avg_meg'}, ...
    tab{contains(tab.drug, 'donepezil'), 'avg_meg'});
fprintf('placebo vs donepezil: t(%d) = %.3f, p = %.4f \n', stats.df, stats.tstat, p);

end