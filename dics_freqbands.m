function [conditions] = dics_freqbands()
% make a grand average of all the TFRs across subjects, and find which
% sensors to use for max visual gamma, motor beta suppression and feedback theta

% from Joram: make sure an integer nr of cycles fits into the time window
% freq_bands = {
% % centfreq bandwidth timewin
%     2        1       [0.1 1.1]  'delta'; % 1-3 Hz, 2 cycles
%     5        2       [0.2 0.8]  'theta'; % 3-7 Hz, 3 cycles
%     10       2       [0.2 0.7]  'alpha'; % 8-12 Hz, 5 cycles
%     20       5       [0.2 0.8]  'beta'; % 15-25 Hz, 12 cycles
% };

%{
from http://www.fieldtriptoolbox.org/tutorial/timefrequencyanalysis/:

cfg.foi, the frequencies of interest, here from 1 Hz to 30 Hz in steps of 2 Hz. 
The step size could be decreased at the expense of computation time and redundancy.
cfg.toi, the time-interval of interest. This vector determines the center times f
or the time windows for which the power values should be calculated. The setting 
cfg.toi = -0.5:0.05:1.5 results in power values from -0.5 to 1.5 s in steps of 50 ms. 
A finer time resolution will give redundant information and longer computation times, but a smoother graphical output.

cfg.t_ftimwin is the length of the sliding time-window in seconds (= tw). We have chosen 
cfg.t_ftimwin = 5./cfg.foi, i.e. 5 cycles per time-window. When choosing this parameter 
it is important that a full number of cycles fit within the time-window for a given frequency.

cfg.tapsmofrq determines the width of frequency smoothing in Hz (= fw). We have chosen 
cfg.tapsmofrq = cfg.foi*0.4, i.e. the smoothing will increase with frequency. Specifying 
larger values will result in more frequency smoothing. For less smoothing you can specify 
smaller values, however, the following relation determined by the Shannon number must hold 
(see Percival and Walden (1993)): K = 2*tw*fw-1, where K is required to be larger than 0. K 
is the number of tapers applied; the more, the greater the smoothing.
%}


% 1. VISUAL alphaband STRONG VS WEAK MOTION
cnt = 1;
conditions(cnt).name                  = 'alpha';
conditions(cnt).timewin               = 0.5;
conditions(cnt).freq                  = 10; % 7-13 Hz
conditions(cnt).tapsmofrq             = 3;
conditions(cnt).crange                = [-0.02 0.02];

% 2. MOTOR BETA BAND
cnt = cnt + 1;
conditions(cnt).name                  = 'beta';
conditions(cnt).timewin               = 0.5; % duration of time window, in seconds
conditions(cnt).freq                  = 24; % 12-36 Hz, 12 cycles in 0.5s
conditions(cnt).tapsmofrq             = 12;
conditions(cnt).crange                = [-0.1 0.1]; % contrast color lim across group

% 3. VISUAL GAMMABAND; motion coherence
cnt = cnt + 1;
conditions(cnt).name                  = 'gamma';
conditions(cnt).timewin               = 0.4;
conditions(cnt).freq                  = 80; % 65-95 Hz
conditions(cnt).tapsmofrq             = 15;
conditions(cnt).crange                = [-0.015 0.015];

% 4. BROADBAND high-frequency
cnt = cnt + 1;
conditions(cnt).name                  = 'broadband';
conditions(cnt).timewin               = 0.4;
conditions(cnt).freq                  = 70; % 65-95 Hz
conditions(cnt).tapsmofrq             = 25;
conditions(cnt).crange                = [-0.015 0.015];

% cnt = cnt + 1;
% conditions(cnt).name                  = 'alpha-narrow';
% conditions(cnt).timewin               = 0.5;
% conditions(cnt).freq                  = 9; % 8-10 Hz
% conditions(cnt).tapsmofrq             = 1;
% conditions(cnt).crange                = [-0.02 0.02];

% do a sanity check - does the combination of time window, frequency and smoothing make it such that there
% are an integer nr of cycles in the window?
for c = 1:length(conditions),
    assert(all(rem(conditions(c).freq ./ conditions(c).timewin, 1) == 0), ...
    	'freq resolution cannot capture all cfg.foi!');

    % K = 2*tw*fw-1
    K = 2*conditions(c).timewin*conditions(c).tapsmofrq;
    assert(K > 0, 'K must be greater than zero');
    assert(mod(K, 1) == 0, 'K must be an integer');
    disp(K)
end
