
function sensorplot_plotTFR(sj, ei)
% plots a set of contrasts for different groups of pre-selected sensors
disp('lets go');

if ~isdeployed,
    addpath(genpath('~/code/MEG'));
    addpath(genpath('~/code/Tools'));
    addpath('~/Documents/fieldtrip');
    ft_defaults; warning off;
end

% for running on stopos
if ~exist('ei', 'var'), ei = 'induced';
end
if ~exist('sj', 'var'), sj = 'GAclean';
end
if ischar(sj) && ~isnan(str2double(sj)), sj = str2double(sj);
end

% ==================================================================
% LOAD IN SUBJECT SPECIFICS
% ==================================================================

subjectdata = subjectspecifics(sj);
load('~/Documents/fieldtrip/template/layout/CTF275_helmet.mat');
lay.outline = lay.outline([1 3:end]); % remove outer bound

close all;
fz = 8;
set(groot, 'defaultaxesfontsize', fz, ...
    'defaultaxestitlefontsizemultiplier', 1, 'defaultaxestitlefontweight', 'normal');
clf;
cmap = coolwarm;

% ==================================================================
% DEFINE CONTRASTS FOR EACH FILE
% ==================================================================

if isnumeric(sj),
    load(sprintf('%s/P%02d-S%d_bl_fb_stimweak.mat', subjectdata.tfrdir, sj, 1));
    [chans, conditions] = sensorplot_defineConditions(freq.label, 1, sj, 1); clear grandavg;
else
    load(sprintf('%s/%s-S%d_freqbl_fb_stimweak.mat', subjectdata.tfrdir, sj, 1));
    [chans, conditions] = sensorplot_defineConditions(grandavg.label, 1, sj, 1); clear grandavg;
end
disp('lets go');

if length(conditions) > 5;
    allconds = conditions;
    allconds = {allconds(1:5) allconds(6:length(conditions))};
else
    allconds = {conditions};
end

for co = 1:length(allconds),
    conditions = allconds{co};
    
    % loop over channels
    for c = 1:length(chans),
        
        if ~strcmp(chans(c).group, 'lateralisation'), clf; end
        for n = 1:length(conditions),
            
            % =========================
            % GET DATA OVER SESSIONS
            % ========================
            
            
            for session = 1:2,
                
                % make sure to get the right channels
                if isnumeric(sj),
                    load(sprintf('%s/P%02d-S%d_bl_ref_all.mat', subjectdata.tfrdir, sj, session));
                    [chans, ~] = sensorplot_defineConditions(freq.label, 1, sj, session); clear grandavg;
                else
                    load(sprintf('%s/%s-S%d_freqbl_ref_all.mat', subjectdata.tfrdir, sj, session));
                    [chans, ~] = sensorplot_defineConditions(grandavg.label, 1, sj, session); clear grandavg;
                end
                
                % GRAB DATA - change 1 to session
                data = getData_TFR(sj, session, conditions(n).name, chans(c).group, chans, ei);
                if strcmp(ei, 'evoked'), conditions(n).crange = conditions(n).crange * 3; end
                
                % if this is a difference map, take diff dat
                topodata = data(1);
                if length(data) > 1,
                    topodata.powspctrm  = data(1).powspctrm - data(2).powspctrm;
                end
                
                % average over participants
                if ~isnumeric(sj) && ~isempty(strfind(topodata.dimord, 'subj')),
                    topodata.powspctrm  = squeeze(mean(topodata.powspctrm));
                    topodata.dimord     = 'chan_freq_time';
                end
                
                alldata{session} = topodata;
                chan_select{session} = chans;
                % SAVE THIS SESSIONS SENSORS
                sensorSelect{session} = chans(c).sens;
                
            end
            
            % sensors: average over the two sessions
            topodata.powspctrm = (alldata{1}.powspctrm + alldata{2}.powspctrm) ./ 2;
            
            % ==================================================================
            % TOPOPLOT
            % ==================================================================
            
            cfgtopo                     = [];
            cfgtopo.marker              = 'off';
            cfgtopo.layout              = lay;
            cfgtopo.comment             = 'no';
            cfgtopo.highlight           = 'on';
            cfgtopo.colormap            = cmap;
            if ~isnumeric(sj),
                cfgtopo.zlim            = conditions(n).crange*0.8; % signal change
            else
                cfgtopo.zlim 			= 'maxmin';
            end
            cfgtopo.renderer            = 'painters';
            
            % only show data if we're plotting a contrast
            if strcmp(conditions(n).name, 'all'),
                cfgtopo.style           = 'blank';
                
            else % 'straight_imsat' uses imagesc, 'straight' uses contourf
                % using 'straight_imsat' saves 2.3 MB per topoplot!
                cfgtopo.style           = 'straight_imsat';
                
                data(1).timename = roundn(data(1).timename, -3);
                % find timewindow that we want to see on topo
                zp  = find(abs(data(1).timename) <  1./data(1).fsample);
                zp(diff(zp) < 10) = [];
                zp  = [zp length(data(1).timename)];
                zp1 = zp(conditions(n).timewin{2}); % index of the period of interest
                zp2 = zp(conditions(n).timewin{2} + 1); % index of the next period
                
                % then find the right timepoints for the window we're interested in
                tp1 = find(data(1).timename(zp1:zp2) > conditions(n).timewin{1}(1), 1, 'first') + zp1;
                tp2 = dsearchn(data(1).timename(zp1:zp2)', conditions(n).timewin{1}(2)) + zp1;
                if conditions(n).timewin{1}(1) <= 0,
                    if  conditions(n).timewin{2} == 1, % pre-reference
                        tp1 = find(data(1).timename(1:zp1) == conditions(n).timewin{1}(1), 1, 'first');
                        tp2 = find(data(1).timename(1:zp2) == conditions(n).timewin{1}(2), 1, 'first');
                    else
                        zp1 = zp(conditions(n).timewin{2} - 1);
                        tp1 = find(data(1).timename(zp1:zp2) == conditions(n).timewin{1}(1), 1, 'first') + zp1;
                    end
                end
                assert(~isempty(tp1), 'did not find the right xlim tp1');
                assert(~isempty(tp2), 'did not find the right xlim tp2');
                
                cfgtopo.xlim = [tp1 tp2]; % use those timewindows
                cfgtopo.ylim = conditions(n).freqwin; % plot the window specified on the topo
            end
            
            % if n == 1, title(gca, sprintf('Session %d', session), 'fontsize', fz); end % which sensor group?
            
            % undocumented fieldtrip: multiple highlights
            chans_s1 = chan_select{1}(c).names;
            chans_s2 = chan_select{2}(c).names;
            cfgtopo.highlightsymbol     = {'.', 'v', '^'};
            cfgtopo.highlightsize       = {4, 0.1, 0.1};
            cfgtopo.highlightchannel    = {intersect(chans_s1, chans_s2), ...
                setdiff(chans_s1, chans_s2), setdiff(chans_s2, chans_s1)};
            cfgtopo.highlightcolor      = 'k';
            
            if ~strcmp(chans(c).group, 'lateralisation'),
                % determine the subplot this will be placed in
                shandle = subplot(max([length(conditions), 5]),5,(n-1)*5+session);
                ft_topoplotER(cfgtopo, topodata);
                prettierTopoCTF275;
                
                % move the second subplot a bit to the right
                if session == 2,
                    shandle.Position(1) = shandle.Position(1) - 0.04;
                end
            end
            
            % ==================================================================
            % TIMECOURSE imagesc
            % ==================================================================
            
            % average over sessions
            subplot(max([length(conditions), 5]),5,(n-1)*5+[3:5]); cla; hold on;
            cfg                 = [];
            cfg.parameter       = 'powspctrm';
            cfg.colormap        = cmap;
            cfg.colorbar        = 'yes';
            cfg.renderer        = 'painters'; % to save to eps
            if ~isnumeric(sj), % only for average
                cfg.zlim        = conditions(n).crange;
            else
                cfg.zlim        = conditions(n).crange * 5;
            end
            
            % fool ft_singleplotTFR into thinking there is one channel
            % otherwise, clusteroutline wont be shown
            switch chans(c).group
                case 'lateralisation'
                    cfg.channel       = 'lat';
                case 'POz'
                    cfg.channel       = 'POz';
                otherwise
                    
                    % make sure to extract channels first and then average over
                    % sessions!
                    s1 = mean(alldata{1}.powspctrm(sensorSelect{1}, :, :));
                    s2 = mean(alldata{2}.powspctrm(sensorSelect{2}, :, :));
                    
                    topodata.powspctrm(end+1, :, :) = squeeze(mean(cat(1, s1, s2)));
                    topodata.label{end+1}           = 'plotchan';
                    cfg.channel                     = 'plotchan';
            end
            
            % ==================================================================
            % add pre-computed stats for contrasts
            % ==================================================================
            
            if strcmp(ei, 'induced'),
                
                if length(data) > 1 && exist(sprintf('%s/%s_%s_%s_%s_freqstats_forTFR.mat', subjectdata.statsdir, ...
                        sj, conditions(n).name{1}, conditions(n).name{2}, chans(c).group), 'file'),
                    disp('adding stats mask');
                    try
                        load(sprintf('%s/%s_%s_%s_%s_freqstats_forTFR.mat', subjectdata.statsdir, ...
                            sj, conditions(n).name{1}, conditions(n).name{2}, chans(c).group));
                        topodata.mask(length(topodata.label), :, :) 	= squeeze(double(stat.mask));
                        
                        % set a logical mask, with an alpha level
                        topodata.mask 									= logical(topodata.mask);
                        cfg.maskparameter 								= 'mask';
                        cfg.maskstyle     								= 'opacity'; % around the cluster
                        cfg.masknans 									= 'yes';
                        cfg.maskalpha                                   = 0.3;
                    end
                    
                elseif length(data) > 1 && exist(sprintf('%s/%s-S%d_%s_%s_%s_freqstats_fullCluster.mat', subjectdata.statsdir, ...
                        sj, 0, conditions(n).name{1}, conditions(n).name{2}, 'allfreq'), 'file'),
                    disp('adding stats mask');
                    load(sprintf('%s/%s-S%d_%s_%s_%s_freqstats_fullCluster.mat', subjectdata.statsdir, ...
                        sj, 0, conditions(n).name{1}, conditions(n).name{2}, 'allfreq'));
                    
                    % collapse over the first dimension??
                    topodata.mask(length(topodata.label), :, :) 	= squeeze(sum(double(stat.mask)));
                    
                    % dont mask fully
                    topodata.mask                                   = logical(topodata.mask);
                    cfg.maskparameter 								= 'mask';
                    cfg.maskstyle     								= 'opacity'; % around the cluster
                    cfg.masknans 									= 'yes';
                    cfg.maskalpha                                   = 0.5;
                    
                end
            end
            
            ft_singleplotTFR(cfg, topodata);
            
            % ==================================================================
            % layout
            % ==================================================================
            
            % make the cluster outlines thinner
            lineObj = findobj(gca, 'type', 'contour');
            for l = 1:length(lineObj),
                if get(lineObj(l), 'LineWidth') == 2,
                    set(lineObj(l), 'LineWidth', 0.1);
                end
            end
            
            set(gca, 'TickDir', 'in', 'YDir', 'normal', 'box', 'off', ...
                'ytick', [5 15 25 40 60 80 100 120], 'yminortick', 'off', 'Linewidth', 0.75);
            set(gca, 'TickDir', 'in', 'YDir', 'normal', 'box', 'off', ...
                'ytick', [20 60 100], 'yminortick', 'off', 'Linewidth', 0.75);
            ylabel('Frequency (Hz)');
            axis tight;
            
            plot_timename(topodata.timename, topodata.fsample, 0.5);
            % mark the difference between the low and high freqs
            plot(get(gca, 'xlim'), [36 36], 'w', 'linewidth', 1.5); % hanning up to 35, multitaper from 36 hz
            
            %             % show the freq range used to define the topoplot box
            %             if ~strcmp(cfgtopo.style, 'blank'),
            %                 for i = cfgtopo.ylim,
            %                     plot([cfgtopo.xlim], [i i], 'k:'); % two horizontal lines
            %                 end
            %                 for i = cfgtopo.xlim,
            %                     plot([i i], cfgtopo.ylim, 'k:');
            %                 end
            %             end
            
            % title
            if length(conditions(n).name) == 1,
                title(gca, conditions(n).name, 'interpreter', 'none', ...
                    'fontsize', fz, 'fontweight', 'normal');
            else
                title(gca, {sprintf('%s - %s', conditions(n).name{:}), ''}, ...
                    'interpreter', 'none', 'fontsize', fz, 'fontweight', 'normal');
            end
            
            if n == length(conditions),
                xlabel('Time (s)');
            else
                set(gca, 'xticklabel', []);
            end
            set(gca, 'fontsize', fz-2);
            
        end
        
        % ==================================================================
        % save figure
        % ==================================================================
        
        if length(conditions(n).name) == 2,
            name = sprintf('%s - %s', conditions(n).name{:});
        else
            name = conditions(n).name{1};
        end
        % save by channel name
        name = chans(c).group;
        prettyColorbar('% signal change', 0.3);
        
        tic;
        if isnumeric(sj),
            [~, h] = suplabel(sprintf('P%02d, %s', sj, name), 't');
            set(h, 'fontsize', 7, 'fontweight', 'bold');
            print(gcf, '-dpdf', sprintf('%s/P%02d_tfr_%s_%s.pdf', subjectdata.figsdir, sj, ei, name));
        else
            [~, h] = suplabel(sprintf('%s n = %d, %s', capitalize(sj(3:end)), numel(subjectdata.(sj(3:end))), name), 't');
            set(h, 'fontsize', 7, 'fontweight', 'bold');
            print(gcf, '-dpdf', sprintf('%s/Figures/%s_tfr_%s_%s_v%d.pdf', subjectdata.path, sj, ei, name, co));
            print(gcf, '-dpng', sprintf('%s/Figures/%s_tfr_%s_%s_v%d.png', subjectdata.path, sj, ei, name, co));
        end
        toc;
    end
end
end