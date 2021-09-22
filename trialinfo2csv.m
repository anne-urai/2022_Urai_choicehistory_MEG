function trialinfo2csv(trl, sj, session, filename)

% remove sample idx
inforows    = find(nanmean(trl, 1) < 100);
samplerows  = find(nanmean(trl, 1) > 100);
% plot(trl(:, samplerows(1:end-1)), '.');

trl = trl(:, [inforows 18]); % also keep the idx
trl(:, 5) = []; % remove double correct

% add a unique idx at the end
% subject, session, block, trialnr
idx = sj * 1000000 + session * 10000 ...
    + trl(:, 6) * 100 + trl(:, 5);
% make sure all idx are unique
assert(numel(unique(idx)) == length(idx), 'idx needs to be unique!');
trl(:, end) = idx;

% specifiy variable names
varnames = {'stim', 'hand', 'resp', 'correct', ...
    'trial', 'block', 'session', 'startHand', 'rt', 'idx'};
t = array2table(trl, 'variablenames', varnames);
assert(all((t.stim(~isnan(t.resp)) == t.resp(~isnan(t.resp))) == t.correct(~isnan(t.resp))), 'correctness does not match stim/resp');

% save
writetable(t, filename);

end

