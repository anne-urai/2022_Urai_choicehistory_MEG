function data = dics_redefinetrials(data, l)
% define timebins to align in nice 50 ms spaced bins

% ==================================================================
% DEFINE THE LOCKING STRUCTURE
% here, take a second extra before and after to get the same number of
% samples in each bin for beamformer sliding window!
% ==================================================================

locking(1).name         = 'ref';
locking(1).offset       = data.trialinfo(:, 2) - data.trialinfo(:, 1);
locking(1).prestim      = 0.5; % 500 ms additional time before fixation trigger
locking(1).poststim     = 2.5;

locking(2).name         = 'stim';
locking(2).offset       = data.trialinfo(:, 5) - data.trialinfo(:, 1);
locking(2).prestim      = 1.5;
locking(2).poststim     = 2;

% time between stim onset and resp: 0.75-3.75s
locking(3).name         = 'resp';
locking(3).offset       = data.trialinfo(:, 9) - data.trialinfo(:, 1);
locking(3).prestim      = 1.5;
locking(3).poststim     = 2.5;

% time between stim offset and resp: 3s
% time between resp and fb: 1.5-3s
locking(4).name         = 'fb';
locking(4).offset       = data.trialinfo(:, 11) - data.trialinfo(:, 1);
locking(4).prestim      = 1.5;
locking(4).poststim     = 2;

% ==================================================================
% RETURN THIS LOCKED DATA
% ==================================================================

try
    % find the samples corresponding to the window we want to see
    cfg                 = [];
    cfg.begsample       = round(locking(l).offset - locking(l).prestim * data.fsample); % take offset into account
    assert(all(cfg.begsample > 0), 'begsample is before onset');
    cfg.endsample       = round(locking(l).offset + locking(l).poststim * data.fsample);
    cfg.offset          = -locking(l).offset;
    data                = redefinetrial(cfg, data);
    
    cfg                 = [];
    cfg.keeptrials      = 'yes';
    cfg.feedback        = 'none';
    data                = ft_timelockanalysis(cfg, data);
    data                = rmfield(data, 'cfg');
catch
    assert(1==0)
end


end
