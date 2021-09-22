function sensorplot_sensordefinition
% from the cluster based permutation stats, get visual and motor sensors +
% frequency band

if ~isdeployed,
    addpath(genpath('~/code/MEG'));
    addpath(genpath('~/code/Tools'));
    addpath('~/Documents/fieldtrip');
    ft_defaults;
end

% for each session, get the occipital and motor channels
subjectdata = subjectspecifics('ga');
sj          = 'GAclean';
[~, conditions] = sensorplot_defineConditions();
nrchans     = 20;

spcnt = 1;
for session = 1:2,

    % occipital chans, stimstrong > stimweak
    load(sprintf('%s/%s-S%d_%s_%s_freqstats.mat', subjectdata.statsdir, ...
        sj, session, conditions(2).name{1}, conditions(2).name{2}));

    % save this channel selection
    sensorDefinition(1).group = 'occipital';
    sensorDefinition(1).names = selectSens(stat, nrchans, 'descend');

    subplot(2,3,spcnt); plotTopo(stat, sensorDefinition(1).names); spcnt = spcnt + 1;
    title(gca, 'occipital');

    % motor chans, left > right
    load(sprintf('%s/%s-S%d_%s_%s_freqstats.mat', subjectdata.statsdir, ...
        sj, session, conditions(3).name{1}, conditions(3).name{2}));

    sensorDefinition(2).group       = 'motor';
    sensorDefinition(2).leftchans   = selectSens(stat, nrchans, 'descend');
    subplot(2,3,spcnt); plotTopo(stat, sensorDefinition(2).leftchans); spcnt = spcnt + 1;
    title(gca, 'left');

    % motor chans, right > left
    sensorDefinition(2).rightchans  = selectSens(stat, nrchans, 'ascend');
    subplot(2,3,spcnt); plotTopo(stat, sensorDefinition(2).rightchans); spcnt = spcnt + 1;
    title(gca, 'right');

    % save for this session, so it can be used on the other session
    savefast(sprintf('%s/%s-S%d_sensorDefinition.mat', subjectdata.statsdir, sj, session), 'sensorDefinition');

end
print(gcf, '-dpdf', sprintf('%s/Figures/sensorDefinition.pdf', subjectdata.path));

end


function sensnames = selectSens(dat, nrSens, sortHow)

sensidx = 0;
load('ctf275_neighb.mat'); % get neighbour struct for clusters
[val, idx]           = sort(dat.stat, sortHow);
cfg                  = [];
cfg.channel          = dat.label;
cfg.neighbours       = neighbours;

% only select those that have at least 1 neighbour in the cluster
cd('~/Documents/fieldtrip/private/');
[connectivity] = channelconnectivity(cfg);
keepgoing = true;
nrsens = nrSens;
for i = 1:50,    % select those that are the most active
    tmpsensidx           = idx(1:i);

    % pick the ones that are neighbouring
    tmpconn      = connectivity(tmpsensidx, tmpsensidx);
    try
      % take only those with neighbours
      tmpsensidx2      = tmpsensidx(sum(tmpconn) > 1);
      % check that we're not too far
      assert(numel(tmpsensidx2) <= nrSens);
      sensidx     = tmpsensidx2;
      nrsens      = nrsens + 1; % get one more channel
    catch
      break;
    end
end

assert(numel(sensidx) <= nrSens);
disp(numel(sensidx));
sensnames = dat.label(sensidx);
end

function plotTopo(dat, sensidx)

% show what this looks like
cfgtopo                     = [];
cfgtopo.marker              = 'off';
cfgtopo.layout              = 'CTF275.lay';
cfgtopo.comment             = 'no';
cfgtopo.highlight           = 'on';
cfgtopo.highlightsymbol     = '.';
cfgtopo.highlightsize       = 5;
cfgtopo.highlightchannel    = sensidx;
cfgtopo.shading             = 'flat';
cfgtopo.style               = 'blank';
cfgtopo.parameter           = 'stat';
ft_topoplotER(cfgtopo, dat);

end
