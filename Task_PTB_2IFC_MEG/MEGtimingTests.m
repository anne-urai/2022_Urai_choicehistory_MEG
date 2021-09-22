% based on trigger channels, do a few timing tests

cd ~/Data/
addpath(pwd);
clear;

% read in the dataset as a continuous segment
cfg                         = [];
cfg.dataset                 = 'testanne_DotsPL_20140430_02.ds';
cfg.continuous              = 'yes'; %read in the data
cfg.precision               = 'single'; %for speed and memory issues
cfg.channel                 = {'UPPT001', 'UPPT002', 'UADC001', 'UADC002'};
data                        = ft_preprocessing(cfg); %load in the segmented data

cfg.channels = 'all';
%ft_databrowser(cfg, data);
dat = data.trial{1};

% extract what's of interest
trig        = dat(1,:);
audiotrig   = dat(3,:);

trig = trig(1:650000);
audiotrig = audiotrig(1:650000);

plot(1:650000, trig, 1:650000, audiotrig);

trigtimes = find(diff(trig)>0);
trigtimes2remove = [(mod(1:length(trigtimes), 5) ==1) + (mod(1:length(trigtimes), 5) == 3) ];
trigtimes(trigtimes2remove==1) = [];% remove the trigger sent at no response, no sound emitted

audiotrigtimes = find(diff(audiotrig)>1);
audiotrigtimes(diff(audiotrigtimes)<10) = []; %remove the trigger timings where there were two events detected, for the up and downgoing audio signal

assert(isequal(size(trigtimes), size(audiotrigtimes)));

trigcompare = audiotrigtimes - trigtimes; % difference is the delay between the parport trigger and the detected audio burst
plot(trigcompare, 'k.')

% remove the feedback, has inherent jitter
feedbackcompare = mod(1:length(trigcompare), 3) == 0;
trigcompare(feedbackcompare) = [];

figure;
plot(trigcompare/data.fsample, '.', 'MarkerSize', 20);
title(sprintf('MEAN %.3f, SD %.3f', mean(trigcompare/data.fsample), std(trigcompare/data.fsample)));
ylabel('Difference between trigger and audio onset');
xlabel('Trials');