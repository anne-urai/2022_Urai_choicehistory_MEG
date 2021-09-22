function [] = sensorplot_clusterStatsTFR_forTFR(n)
% select subsets of trials that we'll look at and compare

if ~isdeployed,
    addpath(genpath('~/code/MEG'));
    addpath(genpath('~/code/Tools'));
    addpath('~/Documents/fieldtrip');
    ft_defaults;  % ft_defaults should work in deployed app?
    warning off;
end

% http://www.fieldtriptoolbox.org/faq/matlab_complains_about_a_missing_or_invalid_mex_file_what_should_i_do/#known_issues_with_spm_mex_files_and_workarounds
global ft_default
ft_default.spmversion = 'spm12';
ft_defaults;

% condition numbers
% n = 2, strong vs weak stim
% n = 3, left vs right buttonpress
% n = 4, correct vs error feedback
% n = 5, prevleft vs prevright buttonpress
% n = 6, alternate vs repeat
% n = 7, previous choice strong vs weak

% for running on stopos
if ischar(n),             n = str2double(n);
end

% define subjects
sj                      = 'GAclean';
subjectdata             = subjectspecifics(sj);
[~, conditions]         = sensorplot_defineConditions();

% use only the locking where we expect the effect
for d = 1:2, % data conditions
    for s = 1:2, % sessions
        locks = {'ref', 'stim', 'resp', 'fb'};
        for l = 1:length(locks),
            
            load(sprintf('%s/%s-S%d_freqbl_%s_%s_allindividuals.mat', ...
                subjectdata.tfrdir, sj, s, locks{l}, conditions(n).name{d}));
            fprintf('%s/%s-S%d_freqbl_%s_%s_allindividuals.mat \n', ...
                subjectdata.tfrdir, sj, s, locks{l}, conditions(n).name{d});
            
            % get channel selection from the other session
            [chans] = sensorplot_defineConditions(grandavg.label, 1, sj, s);
            
            if isequal(conditions(n).name, {'left', 'right'}) | isequal(conditions(n).name, {'prev_left', 'prev_right'}), % lateralisation
                chanNr = 3;
                grandavg_left   = ft_selectdata(struct('avgoverchan', 'yes', 'channel', {chans(chanNr).leftchans.names}), grandavg);
                grandavg_right  = ft_selectdata(struct('avgoverchan', 'yes', 'channel', {chans(chanNr).rightchans.names}), grandavg);
                grandavg        = grandavg_left;
                grandavg.powspctrm = grandavg_left.powspctrm - grandavg_right.powspctrm;
                % grandavg.powspctrm = squeeze(grandavg.powspctrm);
                % grandavg.dimord = 'subj_freq_time';
            else
                chanNr = 1; % occipital sensors
                grandavg        = ft_selectdata(struct('avgoverchan', 'yes', 'channel', {chans(chanNr).names}), grandavg);
            end
            grandavg_locks{l} = grandavg;
        end
        grandavg = grandavg_locks{1};
%         grandavg.powspctrm = cat(4, grandavg_locks{1}.powspctrm, ...
%             grandavg_locks{2}.powspctrm);
        grandavg.powspctrm = cat(4, grandavg_locks{1}.powspctrm, ...
            grandavg_locks{2}.powspctrm, grandavg_locks{3}.powspctrm, grandavg_locks{4}.powspctrm);
        grandavg.timeaxis = cat(2, grandavg_locks{1}.time, ...
            grandavg_locks{2}.time, grandavg_locks{3}.time, grandavg_locks{4}.time);
        grandavg.time = 1:size(grandavg.powspctrm, 4);
        grandavg_sessions{s} = grandavg;
    end
    
    % average over sessions
    grandavg_avgoversessions = grandavg_sessions{1};
    grandavg_avgoversessions.powspctrm =  (grandavg_sessions{1}.powspctrm + grandavg_sessions{2}.powspctrm) ./ 2;
    grandavg_avgoversessions = rmfield(grandavg_avgoversessions, 'cfg'); % keep the structs small
    grandavg_avgoversessions.label = {'virtualsensor'};
    data(d)  = grandavg_avgoversessions;
end

% ==================================================================
% prepare for group-level stats
% ==================================================================

clearvars -except subjectdata conditions data n sj chans chanNr
load('ctf275_neighb.mat'); % get neighbour struct for clusters

cfg                  = [];
cfg.channel          = 'virtualsensor';
cfg.neighbours       = [];
cfg.minnbchan        = 0; % 3, according to Tom (two chans can form weird bridges)
cfg.parameter        = 'powspctrm';
cfg.method           = 'montecarlo';
cfg.statistic        = 'ft_statfun_depsamplesT'; % within-subject contrast

cfg.correctm         = 'cluster';
cfg.clustertail      = 0; % two-tailed
cfg.clusteralpha     = 0.05;
cfg.clusterstatistic = 'maxsum'; % sum all t-values in a cluster

cfg.tail             = 0; % two-tailed
cfg.alpha            = 0.05; % alpha, see below
cfg.correcttail      = 'alpha'; % see http://www.fieldtriptoolbox.org/faq/why_should_i_use_the_cfg.correcttail_option_when_using_statistics_montecarlo

cfg.numrandomization = 10000;
% cfg.feedback         = 'no'; % makes logfiles easier to read
cfg.randomseed       = 42; % keep this for reproducibility

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
disp(stat);
disp(sum(stat.mask(:)));

stat.cfg = cfg;
stat.timeaxis = data(1).timeaxis;

% save with the name of this contrast, also make sure to save the random seed
save(sprintf('%s/%s_%s_%s_%s_freqstats_forTFR.mat', subjectdata.statsdir, ...
    sj, conditions(n).name{1}, conditions(n).name{2}, chans(chanNr).group), 'stat');

end
