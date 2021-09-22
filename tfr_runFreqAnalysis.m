function freq = tfr_runFreqAnalysis(data)
  % We used sliding window Fourier transform (Mitra and Pesa- ran 1999)
  % (window length: 400 ms, step size: 50 ms) to calculate time-frequency
  % representations of the MEG power (spectrograms) for the two gradiometers
  % of each sensor and each single trial. We used a single Hanning taper for
  % the frequency range 3?35 Hz (frequency resolution: 2.5 Hz, bin size: 1 Hz)
  % and the multi-taper technique for the frequency range 36-140 Hz (spectral
  % smoothing: 8 Hz, bin size: 2 Hz, 5 tapers). After time-frequency analysis,
  % the two orthogonal planar gradiometers of each sensor were combined by
  % taking the sum of their power values. Kloosterman et al. (2015)

% define neighbours based on our template
cfg                 = [];
cfg.method          = 'template';
cfg.layout          = 'CTF275';
neighbours          = ft_prepare_neighbours(cfg);

% keep nonMEGdata
cfg                 = [];
cfg.channel         = {'POz', 'EKG'};
nonMEGdata          = ft_selectdata(cfg, data);
nonMEGdata          = rmfield(nonMEGdata, 'cfg');

% compute planar gradiometers for MEG sensors
cfg                 = [];
cfg.feedback        = 'no';
cfg.method          = 'template';
cfg.planarmethod    = 'sincos';
cfg.channel         = 'MEG';
cfg.neighbours      = neighbours;
data                = ft_megplanar(cfg, data);

% ==================================================================
% HIGH FREQUENCY USING MULTITAPER
% ==================================================================

cfg                 = [];
cfg.output          = 'pow';
cfg.method          = 'mtmconvol';
cfg.taper           = 'dpss';
cfg.keeptrials      = 'yes';
cfg.keeptapers      = 'no';
cfg.precision       = 'single'; % saves disk space
cfg.feedback        = 'none'; % improve readability of logfiles
cfg.polyremoval     = 1; % detrend and demean

% make nice timebins at each 50 ms, will include 0 point
mintime = data.time(1); maxtime = data.time(end);
toi = floor(mintime) : 0.05 : ceil(maxtime);
toi(toi < mintime) = []; toi(toi > maxtime) = [];

cfg.toi             = toi; % all time within each locking
cfg.pad             = 2; % pad to a fixed number of seconds before TFR

% cfg.foi/T should be integer numbers to avoid spectral leakage
cfg.foi             = 38:cfg.pad:120; % low + high freq together, Rayleigh = 0.5 Hz, Nyquist = 200 Hz
cfg.t_ftimwin       = ones(1, length(cfg.foi)) .* 0.4;
cfg.tapsmofrq       = ones(1, length(cfg.foi)) .* 5; % tapsmofrq specifies half the spectral concentration

% http://mailman.science.ru.nl/pipermail/fieldtrip/2007-August/001327.html
% 1. Do the cfg.t_ftimwins yield an integer number of cycles for each requested frequency?
% 2. Is the length of my data such, that the frequency resolution 1/T can capture all cfg.foi?
% This means, in other words, that cfg.foi/T should be integer numbers.
assert(all(rem(cfg.foi ./ cfg.t_ftimwin, 1) == 0), 'freq resolution cannot capture all cfg.foi!');
assert(all(rem(cfg.foi ./ cfg.pad, 1) == 0), 'freq resolution cannot capture all cfg.foi!');

freqHigh            = ft_freqanalysis(cfg, data);
assert(isequal(freqHigh.freq, cfg.foi), '! spectral estimation returned different foi, double-check settings !');

% combine the planar gradiometers and save the file
freqHigh            = ft_combineplanar([], freqHigh);

% ==================================================================
% LOW FREQUENCY USING HANNING WINDOW
% ==================================================================

% keep all settings except from the taper and foi
cfg.taper           = 'hanning';
cfg.foi             = 3:1:36;
cfg.t_ftimwin       = ones(1, length(cfg.foi)) .* 0.4;
cfg.tapsmofrq       = [];

freqLow             = ft_freqanalysis(cfg, data);
assert(isequal(freqLow.freq, cfg.foi), '! spectral estimation returned different foi, double-check settings !');
freqLow             = ft_combineplanar([], freqLow); % combine planar

% ==================================================================
% APPEND LOW AND HIGH FREQ
% ==================================================================

disp('appending low and high frequencies...');
freq            = freqLow;
freq.freq       = [freqLow.freq freqHigh.freq];
freq.powspctrm  = cat(3, freqLow.powspctrm, freqHigh.powspctrm);
freq            = rmfield(freq, 'cfg'); % keep it small
freq            = rmfield(freq, 'cumtapcnt'); % always 5, redundant

end
