function data = redefinetrial(cfg, data)
% replaces ft_redefinetrial, much faster
disp('redefining trial');
Ntrial = length(data.trial);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% select a latency window from each trial based on begin and/or end sample
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

begsample = cfg.begsample(:);
endsample = cfg.endsample(:);
if length(begsample)==1
    begsample = repmat(begsample, Ntrial, 1);
end
if length(endsample)==1
    endsample = repmat(endsample, Ntrial, 1);
end
for i=1:Ntrial,
    try
        data.trial{i} = data.trial{i}(:, begsample(i):endsample(i));
        data.time{i}  = data.time{i} (   begsample(i):endsample(i));
    catch
        fprintf('ERROR trial %d, begsmp %d, endsmp %d, trllength %d \n', i, begsample(i), endsample(i), length(data.trial{i}));
        assert(1==0);
    end
end

% also correct the sampleinfo
if isfield(data, 'sampleinfo')
    data.sampleinfo(:, 1) = data.sampleinfo(:, 1) + begsample - 1;
    data.sampleinfo(:, 2) = data.sampleinfo(:, 1) + endsample - begsample;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% shift the time axis from each trial
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
offset = cfg.offset(:);
if length(cfg.offset)==1
    offset = repmat(offset, Ntrial, 1);
end
for i=1:Ntrial
    data.time{i} = data.time{i} + offset(i)/data.fsample;
end

end