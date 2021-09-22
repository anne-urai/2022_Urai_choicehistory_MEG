function [] = heartrate_summarize()
% for each file, read in the full timecourse of channel EEG059 and compute
% heart rate. Then compare this over the two sessions, for each drug group

addpath(genpath('~/code/MEG'));
addpath('~/Documents/fieldtrip/');
ft_defaults; warning off;

% get Sven's rejection matrix
load(sprintf('%s/EKG/heartRateReject_Sven.mat', subjectdata.path));
reject.Sven         = APPROVE_TRIAL;
reject.bpmTooLow    = nan(size(reject.Sven));

% ==================================================================
% EXTRACT ALL THE HEARTRATES
% ==================================================================

subjectdata = subjectspecifics('ga');
subjects    = subjectdata.all;

% preallocate variables
varnames = {'subjnr', 'session', 'block', 'heartrate'};
results = array2table(nan(length(subjectdata.all)*20, length(varnames)), 'variablenames', varnames);
results.drug = repmat({'NaN'}, length(subjectdata.all)*20, 1);

icnt = 0;
for sj = (unique(subjects)),
    subjectdata = subjectspecifics(sj);
    for session = 1:length(subjectdata.session),
        
        % ==================================================================
        % preprocess all the EKG signals
        % ==================================================================
        
        if ~exist(sprintf('%s/EKG/P%02d-S%d_ekg.mat', subjectdata.path, sj, session), 'file'),
            continue;
        end
        
        load(sprintf('%s/EKG/P%02d-S%d_ekg.mat', subjectdata.path, sj, session));
        
        cfg             = [];
        cfg.demean      = 'yes';
        cfg.detrend     = 'yes';
        cfg.resamplefs  = 100;
        data            = ft_resampledata(cfg, data);
        
        cfg             = [];
        cfg.bpfreq 		= [5 40];
        cfg.bpfilter    = 'yes';
        data 			= ft_preprocessing(cfg, data);
        
        % do peakdetect on each 'trial' (=block)
        for t = 1:length(data.trial),
            
            icnt                    = icnt + 1;
            results.subjnr(icnt)    = sj;
            results.session(icnt)   = session;
            results.block(icnt)     = t;
            results.drug(icnt)      = {subjectdata.drug};
            
            % switch so that peaks are upwards
            data.trial{t} = -data.trial{t};
            
            % ==================================================================
            % HEART RATE
            % ==================================================================
            
            maxbpm = 150; % maximum heartrate I think is acceptable
            distancebetweenpeaks = 1 / (maxbpm / 60) * data.fsample; % convert into distance between peaks
            [vals, peaklocations] = findpeaks(double(data.trial{t}), ...
                'MinPeakDistance', distancebetweenpeaks, 'MinPeakHeight', 5*10^-4);
            
            % visualize the detection
            if 0,
                clf;
                totallength = max(data.time{t});
                nsubpl = 10;
                for sp = 1:nsubpl,
                    subplot(nsubpl,1,sp);
                    plot(data.time{t}, data.trial{t}, 'k'); hold on;
                    plot(data.time{t}(peaklocations), data.trial{t}(peaklocations), 'r.');
                    xlim([(sp-1)*totallength/nsubpl (sp)*totallength/nsubpl]);
                    set(gca, 'xtick', [], 'ytick', []);
                    axis tight; box off;
                    xlim([(sp-1)*totallength/nsubpl (sp)*totallength/nsubpl]);
                end
                suplabel(sprintf('/P%02d-S%d_allEKG.mat', sj, session), 't');
                waitforbuttonpress; % look at the performance of the peakdetection
            end
            
            % save into matrix
            bpm = length(peaklocations) / range(data.time{t}) * 60;
            
            if bpm < 50,
                % in some cases, the EKG electrode was loose so there is no heart signal
                % assuming we have no athletes in the sample...
                reject.bpmTooLow(sj, t, session) = 0;
            else
                reject.bpmTooLow(sj, t, session) = 1;
            end
            
            % use Sven's visual rejection to decide if we use this sample
            switch reject.Sven(sj, t, session)
                case 1
                    keep = 1;
                case 0
                    keep = 0;
            end
           
            if bpm < 50,
                keep = 0; 
            end
            
            results.heartrate(icnt) = bpm;
            results.keep(icnt)      = keep;
               
            % ==================================================================
            % HEART RATE VARIABILITY
            % ==================================================================
            
            interBeatInterval = diff(data.time{t}(peaklocations));
            
            % now, how to convert this into 1 metric of variability?
   
        end
    end
end

results(isnan(results.subjnr), :)  = [];
writetable(results, '~/Data/MEG-PL/Data/CSV/heartrate.csv');

end
% ==================================================================
% PLOT THE OUTCOME OF HEARTRATE OVER SESSIONS
% ==================================================================
% 
% addpath('~/Documents/gramm');
% results = readtable('~/Data/MEG-PL/Data/CSV/heartrate.csv');
% 
% for f = [0],
%     
%     % baseline correct by pre-drug heart rate
%     if f == 1,
%         for sj = unique(results.subjnr)',
%             subjectdata = subjectspecifics(sj);
%             for session = 1:length(subjectdata.session),
%                 results.heartrate(results.subjnr == sj & results.session == session) = ...
%                     results.heartrate(results.subjnr == sj & results.session == session) - ...
%                     nanmean(subjectdata.session(session).heartrate);
%             end
%         end
%     end
%     
%     close all; clear g;
%     % reshape into a timecourse from S1 to S2
%     g(1,1) = gramm('x', results.block, 'y', results.heartrate,...
%         'color', results.drug, 'group', results.subjnr, 'subset', (results.block <= 10 & results.keep ==1));
%     g(1,1).set_names('x', 'Block', 'y', 'BPM', 'column', 'Session');
%     g(1,1).geom_line;
%     g(1,1).facet_grid([], results.session, 'force_ticks', false);
%     g(1,1).axe_property('xtick', 1:10, 'xlim', [0.5 10.1]);
%     
%     g(2,1) = gramm('x', results.block, 'y', results.heartrate,...
%         'color', results.drug, 'group', results.drug, 'subset', (results.block <= 10 & results.keep ==1));
%     g(2,1).axe_property('xtick', 1:10, 'xlim', [0.5 10.1]);
%     g(2,1).stat_summary('type', 'fitnormalci', ...
%         'geom', 'area', 'setylim', 'true');
%     g(2,1).facet_grid([], results.session, 'force_ticks', false);
%     g(2,1).set_names('x', 'Block', 'y', 'BPM', 'column', 'Session');
%     g.draw;
%     
%     subjectdata = subjectspecifics('ga');
%     set(gcf, 'PaperPositionMode', 'auto'); % avoid a warning
%     print(gcf, '-dpdf', sprintf('%s/Figures/heartrate_bl%d.pdf', subjectdata.path, f));
%     
% end