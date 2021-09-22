function [] = sensorplot_clusterStatsTFR_defineSens(n, sessions)
% select subsets of trials that we'll look at and compare

if ~isdeployed,
    addpath(genpath('~/code/MEG'));
    addpath(genpath('~/code/Tools'));
    addpath('~/Documents/fieldtrip');
    ft_defaults;  % ft_defaults should work in deployed app?
    warning off;
end

% run for n = 2 (visual gamma) and n = 4 (motor beta)
% add in: n = 7 (previous choice)

if ~exist('sessions', 'var'),   sessions = [1 2]; end

% for running on stopos
if ischar(n),             n = str2double(n); end
if ischar(sessions),       sessions = str2double(sessions); end

% define subjects
sj              = 'GAclean';
subjectdata     = subjectspecifics(sj);
[~, conditions] = sensorplot_defineConditions();

for session = sessions,

% use only the locking where we expect the effect
for d = 1:2,
    locks = {'ref', 'stim', 'resp', 'fb'};
    load(sprintf('%s/%s-S%d_freqbl_%s_%s_allindividuals.mat', ...
        subjectdata.tfrdir, sj, session, locks{conditions(n).timewin{2}}, conditions(n).name{d}));
    fprintf('%s/%s-S%d_freqbl_%s_%s_allindividuals.mat \n', ...
        subjectdata.tfrdir, sj, session, locks{conditions(n).timewin{2}}, conditions(n).name{d});

    % only use a small time window
    grandavg = ft_selectdata(struct('latency', conditions(n).timewin{1}, ...
        'avgovertime', 'yes', 'frequency', conditions(n).freqwin, 'avgoverfreq', 'yes'), grandavg);
    grandavg = rmfield(grandavg, 'cfg'); % keep the structs small
    grandavg.dimord = 'subj_chan';
    data(d)  = grandavg;
end

% ==================================================================
% prepare for group-level stats
% ==================================================================

load('ctf275_neighb.mat'); % get neighbour struct for clusters

cfg                  = [];
cfg.channel          = 'MEG'; % use only subset of sensors
cfg.minnbchan        = 3; % 3, according to Tom (two chans can form weird bridges)
cfg.neighbours       = neighbours;
cfg.parameter        = 'powspctrm';
cfg.method           = 'montecarlo';
cfg.statistic        = 'ft_statfun_depsamplesT'; % within-subject contrast

cfg.correctm         = 'cluster';
cfg.clustertail      = 0; % two-tailed
cfg.clusteralpha     = 0.01;
cfg.clusterstatistic = 'maxsum'; % sum all t-values in a cluster

cfg.tail             = 0; % two-tailed
cfg.alpha            = 0.01; % alpha, see below
cfg.correcttail      = 'prob'; % see http://www.fieldtriptoolbox.org/faq/why_should_i_use_the_cfg.correcttail_option_when_using_statistics_montecarlo

cfg.numrandomization = 10000;
cfg.randomseed       = sum(100*clock); % keep this for reproducibility

% paired design, within subject
subj = size(data(1).powspctrm, 1);
design = zeros(2,2*subj);
for i = 1:subj
    design(1,i) = i;
end
for i = 1:subj
    design(1,subj+i) = i;
end
design(2,1:subj)        = 1;
design(2,subj+1:2*subj) = 2;
cfg.design   = design;
cfg.uvar     = 1;
cfg.ivar     = 2;

stat         = ft_freqstatistics(cfg, data(1), data(2));
assert(1==0)

% save with the name of this contrast, also make sure to save the random seed
save(sprintf('%s/%s-S%d_%s_%s_freqstats.mat', subjectdata.statsdir, ...
    sj, session, conditions(n).name{1}, conditions(n).name{2}), 'stat', 'cfg');
end

end
