function [newdata] = getData_TFR_alltrials(sj, session)
% call for plotting or stats

subjectdata = subjectspecifics(sj);

% load in the right file
% take baseline corrected one - in dB, from across-trial basline
locks = {'ref', 'stim', 'resp', 'fb'};
for l = fliplr(1:length(locks)),
    load(sprintf('%s/P%02d-S%d_commonbl_%s.mat', ...
        subjectdata.tfrdir, sj, session, locks{l}));
    fprintf('%s/P%02d-S%d_commonbl_%s.mat \n', ...
        subjectdata.tfrdir, sj, session, locks{l});
    ldata{l}         = freq;
end

newdata.label    = ldata{1}.label;
newdata.freq     = ldata{1}.freq;
newdata.powspctrm      = squeeze(cat(4, ...
    ldata{1}.powspctrm, ...
    ldata{2}.powspctrm, ...
    ldata{3}.powspctrm, ...
    ldata{4}.powspctrm));
newdata.timename    = [ldata{1}.time ldata{2}.time ldata{3}.time ldata{4}.time];
newdata.trialinfo   = ldata{1}.trialinfo; % for idx
newdata.trialinfo(:, end+1) = sj;

% fool fieldtrip into thinking that the time axis increases
newdata.time       = 1:length(newdata.timename);
newdata.fsample    = 1./ unique(round(diff(ldata{1}.time), 4)); % time steps
newdata.dimord     = 'rpt_chan_freq_time';
clear ldata;

end
