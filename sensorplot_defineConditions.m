function [chans, conditions] = sensorplot_defineConditions(labels, computeContrasts, sj, session)
% make a grand average of all the TFRs across subjects, and find which
% sensors to use for max visual gamma, motor beta suppression and feedback theta

% ==================================================================
% define conditions
% ==================================================================

cnt = 1;
conditions(cnt).name    = {'all'};
conditions(cnt).timewin = {[-0.2 0], 1}; % baseline interval
conditions(cnt).freqwin = [2 120];
conditions(cnt).crange  = [-10 10];

% all parameters from Siegel et al. 2006 - sensory evidence, occipital gamma
cnt = cnt + 1;
conditions(cnt).name    = {'stimstrong', 'stimweak'};
conditions(cnt).timewin = {[0.15 0.75], 2}; % stim interval
conditions(cnt).freqwin = [65 95]; % avoid SSVEP
conditions(cnt).crange  = [-2 2];

% There is a very clear relative suppression with a minimum somewhere around 10 Hz
% in the strong - weak difference spectrum. This has escaped my attention so far,
% but it is much in line with what Markus and I found back then and might be a very
% interesting additional canditate for top-down effects. So, all visual cortex analyses
% should be done on this band, as well as on the gamma part above the SSVEP.
% (Note that the spectral profile of this sensory power suppression effect differs
% slightly from the overall task induced response, which I find quite interesting)
% email Tobi 27.06.2017

% cnt = cnt + 1;
% conditions(cnt).name    = {'stimstrong', 'stimweak'};
% conditions(cnt).timewin = {[0.15 0.75], 2}; % stim interval
% conditions(cnt).freqwin = [8 12]; % alpha
% conditions(cnt).crange  = [-4 4];

% all parameters from Donner et al. 2009 - beta buildup
cnt = cnt + 1;
conditions(cnt).name    = {'left', 'right'};
conditions(cnt).timewin = {[-0.25 0], 3}; % resp interval
conditions(cnt).freqwin = [12 36];
conditions(cnt).crange  = [-25 25];

% % correct vs error - theta, after feedback
% cnt = cnt + 1;
% conditions(cnt).name     = {'error', 'correct'};
% conditions(cnt).timewin  = {[0.2 0.7], 4}; %% after response, uncertainty
% conditions(cnt).freqwin  = [8 12]; % alpha
% conditions(cnt).crange   = [-40 40];

% previous choice leads to higher visual gammma
cnt = cnt + 1;
conditions(cnt).name     = {'prev_respstrong', 'prev_respweak'};
conditions(cnt).timewin  = {[0 0.75], 1}; % reference interval
conditions(cnt).freqwin  = [65 95];
conditions(cnt).crange   = [-1 1];

% replicate Pape & Siegel Figure 3A
cnt = cnt + 1;
conditions(cnt).name     = {'prev_left', 'prev_right'};
conditions(cnt).timewin  = {[-0.25 0], 1}; % reference interval
conditions(cnt).freqwin  = [12 36];
conditions(cnt).crange   = [-10 10];
% 
% % previous choice leads to higher visual alpha
% cnt = cnt + 1;
% conditions(cnt).name     = {'alternation', 'repetition'};
% conditions(cnt).timewin  = {[-0.1 1], 3}; % reference interval
% conditions(cnt).freqwin  = [5 25]; % refine
% conditions(cnt).crange   = [-8 8];

% previous choice leads to higher visual gammma
cnt = cnt + 1;
conditions(cnt).name     = {'prev_respstrong', 'prev_respweak'};
conditions(cnt).timewin  = {[-0.25 1], 1}; % reference interval
conditions(cnt).freqwin  = [100 110];
conditions(cnt).crange   = [-2 2];

% previous choice leads to higher visual gammma
cnt = cnt + 1;
conditions(cnt).name     = {'prev_respstrong', 'prev_respweak'};
conditions(cnt).timewin  = {[-0.25 1], 1}; % reference interval
conditions(cnt).freqwin  = [60 70];
conditions(cnt).crange   = [-2 2];

cnt = cnt + 1;
conditions(cnt).name     = {'prev_respstrong', 'prev_respweak'};
conditions(cnt).timewin  = {[-0.25 0.25], 1}; % reference interval
conditions(cnt).freqwin  = [10 20];
conditions(cnt).crange   = [-2 2];

cnt = cnt + 1;
conditions(cnt).name     = {'prev_respstrong', 'prev_respweak'};
conditions(cnt).timewin  = {[1 1.25], 1}; % reference interval
conditions(cnt).freqwin  = [10 20];
conditions(cnt).crange   = [-2 2];

% cnt = cnt + 1;
% conditions(cnt).name     = {'prev_respstrong', 'prev_respweak'};
% conditions(cnt).timewin  = {[-1 1.25], 1}; % reference interval
% conditions(cnt).freqwin  = [10 20];
% conditions(cnt).crange   = [-2 2];

% ==================================================================
% POz - one EEG channel
% ==================================================================

if nargin == 0,
    chans = [];
else

    if ~exist('computeContrasts', 'var'); computeContrasts = false; end

    if computeContrasts,
        % load pre-computed cluster statistics
        subjectdata = subjectspecifics('ga');
        load(sprintf('%s/%s-S%d_sensorDefinition.mat', ...
            subjectdata.statsdir, 'GAclean', -1*(session-1)+2));
    end

    if ~exist('labels', 'var') || isempty(labels),
        subjectdata = subjectspecifics(sj);
        load(sprintf('%s/P%02d-S%d_bl_ref.mat', subjectdata.tfrdir, sj, session));
        labels = freq.label;
    end

    cnt                           = 1;

    % ==================================================================
    % OCCIPITAL
    % ==================================================================

    chans(cnt).group              = 'occipital';
    if computeContrasts,
        % from stats
        chans(cnt).names = sensorDefinition(1).names;
    else
        % all occipital chans
        chans(cnt).names = labels(find(~cellfun(@isempty, strfind(labels, 'O'))));
    end
    chans(cnt).sens    = findChanIdx(chans(cnt).names, labels);

    % ==================================================================
    % MOTOR
    % ==================================================================

    cnt = cnt + 1;
    chans(cnt).group = 'motor';

    if computeContrasts,
        % get sensors that participate in left vs right cluster
        rightchans.names    = sensorDefinition(2).rightchans;
        leftchans.names     = sensorDefinition(2).leftchans;
    else
        rightchans.names    = labels(find(~cellfun(@isempty, strfind(labels, 'RC'))));
        leftchans.names     = labels(find(~cellfun(@isempty, strfind(labels, 'LC'))));
    end

    rightchans.sens     = findChanIdx(rightchans.names, labels);
    leftchans.sens      = findChanIdx(leftchans.names, labels);

    chans(cnt).names    = [leftchans.names; rightchans.names];
    chans(cnt).sens     = findChanIdx(chans(cnt).names, labels);

    % ==================================================================
    % LATERALISATION, VIRTUAL CHANNEL WILL BE CREATED
    % ==================================================================

    cnt = cnt + 1;
    chans(cnt).group        = 'lateralisation';
    chans(cnt).names        = 'lat';
    chans(cnt).sens         = length(labels) + 1;

    chans(cnt).leftchans    = leftchans;
    chans(cnt).rightchans   = rightchans;

    % ==================================================================
    % LEFT + RIGHT SEPARATELY
    % ==================================================================

    cnt = cnt + 1;
    chans(cnt).group        = 'motorleft';
    chans(cnt).names        = leftchans.names;
    chans(cnt).sens         = leftchans.sens;

    cnt = cnt + 1;
    chans(cnt).group        = 'motorright';
    chans(cnt).names        = rightchans.names;
    chans(cnt).sens         = rightchans.sens;

    % ==================================================================
    % PARIETAL
    % ==================================================================

    cnt 			 = cnt + 1;
    chans(cnt).group = 'parietal';

    % remove those that are already in the occipital or motor cluster
    l 				      = labels(find(~cellfun(@isempty, strfind(labels, 'P'))));
    [~, duplicateSensory] = intersect(l, chans(1).names);
    [~, duplicateMotor]   = intersect(l, chans(2).names);
    l(sort([duplicateSensory; duplicateMotor])) = [];

    chans(cnt).names   = l;
    chans(cnt).sens    = findChanIdx(chans(cnt).names, labels);

    % ==================================================================
    % CENTRAL
    % ==================================================================

    cnt 			 = cnt + 1;
    chans(cnt).group = 'central';

    % remove those that are already in the occipital or motor cluster
    l 				      = labels(find(~cellfun(@isempty, strfind(labels, 'C'))));
    [~, duplicateSensory] = intersect(l, chans(1).names);
    [~, duplicateMotor]   = intersect(l, chans(2).names);
    l(sort([duplicateSensory; duplicateMotor])) = [];

    chans(cnt).names   = l;
    chans(cnt).sens    = findChanIdx(chans(cnt).names, labels);

    % ==================================================================
    % FRONTAL
    % ==================================================================

    cnt 			 = cnt + 1;
    chans(cnt).group = 'frontal';

    % remove those that are already in the occipital or motor cluster
    l 				      = labels(find(~cellfun(@isempty, strfind(labels, 'F'))));
    [~, duplicateSensory] = intersect(l, chans(1).names);
    [~, duplicateMotor]   = intersect(l, chans(2).names);
    l(sort([duplicateSensory; duplicateMotor])) = [];

    chans(cnt).names   = l;
    chans(cnt).sens    = findChanIdx(chans(cnt).names, labels);

    % ==================================================================
    % ALL OCCIPITAL
    % ==================================================================

    cnt = cnt + 1;
    chans(cnt).group              = 'occipital_all';
    % all occipital chans
    chans(cnt).names = labels(find(~cellfun(@isempty, strfind(labels, 'O'))));
    chans(cnt).sens    = findChanIdx(chans(cnt).names, labels);

    % ==================================================================
    % POz
    % ==================================================================

    % try
    %
    %     cnt                           = cnt + 1;
    %     chans(cnt).group   = 'POz';
    %     chans(cnt).names   = labels(find(~cellfun(@isempty, strfind(labels, 'POz'))));
    %     chans(cnt).sens    = findChanIdx(chans(cnt).names, labels);
    %     assert(~isempty(chans(cnt).sens), 'could not find POz channel');
    %
    %     cnt                           = cnt + 1;
    %     % all occipital chans
    %     chans(cnt).group   = 'POz_unfiltered';
    %     chans(cnt).names   = labels(find(~cellfun(@isempty, strfind(labels, 'POz_unfiltered'))));
    %     chans(cnt).sens    = findChanIdx(chans(cnt).names, labels);
    %     assert(~isempty(chans(cnt).sens), 'could not find POz channel');
    % catch
    %     cnt = cnt - 1; % ignore for TFRs
    % end

    % ==================================================================
    % PLOT TOPOGRAPHY
    % ==================================================================

    if 0,
        load('~/Documents/fieldtrip/template/layout/CTF275_helmet.mat');
        lay.outline = lay.outline([1 3:end]); % remove outer bound

        clf;
        cfg                     = [];
        cfg.marker              = 'off';
        cfg.layout              = lay;
        cfg.comment             = 'no';
        usegroups               = find(cellfun(@isempty, (strfind({chans(:).group}, 'lateralisation'))));
        cfg.highlightchannel    = {chans(usegroups).names};
        cfg.highlight           = {chans(usegroups).group};
        cfg.highlightsymbol     = repmat({'.'}, 1, numel(usegroups));
        cfg.highlightsize       = repmat({20}, 1, numel(usegroups));

        % give every changroup its own color
        colors = linspecer(numel(usegroups)); highlightcolor = {};
        for g = 1:length(usegroups),
            highlightcolor = [highlightcolor; {colors(g, :)}];
        end
        cfg.highlightcolor      = highlightcolor;
        cfg.renderer            = 'painters';
        cfg.style               = 'blank';

        % plot the thing
        sj = 2;
        subjectdata = subjectspecifics(sj);
        load(sprintf('%s/P%02d-S%d_bl_ref_all.mat', subjectdata.tfrdir, sj, session));
        ft_topoplotER(cfg, freq);
        prettierTopoCTF275;
        print(gcf, '-dpdf', sprintf('%s/Figures/sensors_S%d.pdf', subjectdata.path, session));
    end
end

end % function

% ==================================================================
% subfunction to get channel name indices
% ==================================================================

function idx = findChanIdx(names, labels)
% finds the numbers of specific channel labels

idx = [];
for n = 1:length(names),
    i   = find(strcmp(names{n}, labels));
    idx = [idx i];
end

end
