function preproc_writeCSV()

if ~isdeployed,
    addpath(genpath('~/code/MEG'));
    addpath(genpath('~/code/Tools'));
    addpath('~/Documents/fieldtrip');
    ft_defaults;
    warning off; % lots of FT crap
end

allsubjectdata = subjectspecifics('ga');

if ~exist(sprintf('%s/allsubjects_meg.csv', allsubjectdata.csvdir), 'file'),
    for sj = allsubjectdata.all,
        subjectdata = subjectspecifics(sj);
        
        if exist(sprintf('%s/P%02d_meg.csv', subjectdata.csvdir, sj), 'file'),
            continue;
        end
        
        cleandat = {};
        alldat = {};
        
        for session = 1:length(subjectdata.session),
            for rec = subjectdata.session(session).recsorder,
                cleandat{end+1} = readtable(sprintf('%s/P%02d-S%d_rec%d_meg_clean.csv', subjectdata.csvdir, sj, session, rec));
                alldat{end+1}   = readtable(sprintf('%s/P%02d-S%d_rec%d_meg_all.csv', subjectdata.csvdir, sj, session, rec));
            end
        end
        
        % merge for this subject
        alldat      = cat(1, alldat{:});
        cleandat    = cat(1, cleandat{:});
        
        % indicate which variables have been removed in MEG preproc
        alldat.keep_meg = ismember(alldat.idx, cleandat.idx);
        fprintf('Subject %02d, keeping %.1f %% of trials, %d clean trials total \n', sj, 100*mean(alldat.keep_meg), sum(alldat.keep_meg));
        
        % rename some for easier reading
        alldat.Properties.VariableNames{'stim'}      = 'stimulus';
        alldat.Properties.VariableNames{'resp'}      = 'response';
        alldat.Properties.VariableNames{'startHand'} = 'start_hand';
        
        writetable(alldat, sprintf('%s/P%02d_meg.csv', subjectdata.csvdir, sj));
        
    end
    
    %% ONE BIG TABLE ACROSS SUBJECTS
    alldat = {};
    for sj = allsubjectdata.all,
        subjectdata = subjectspecifics(sj);
        
        dat = readtable(sprintf('%s/P%02d_meg.csv', subjectdata.csvdir, sj));
        dat.subj_idx = sj * ones(size(dat.stimulus));
        alldat{end+1} = dat;
    end
    
    alldat      = cat(1, alldat{:});
    writetable(alldat, sprintf('%s/allsubjects_meg.csv', allsubjectdata.csvdir));
    fprintf('%s/allsubjects_meg.csv \n', allsubjectdata.csvdir);
end


%% DETERMINE WHICH SUBJECTS ARE CLEAN
alldat   = readtable(sprintf('%s/allsubjects_meg.csv', allsubjectdata.csvdir));
writetable(alldat, sprintf('%s/allsubjects_meg_orig.csv', allsubjectdata.csvdir));

[gr, sj, sess] = findgroups(alldat.subj_idx, alldat.session);
cleantrials = splitapply(@sum, alldat.keep_meg, gr);
percentage = splitapply(@mean, alldat.keep_meg, gr);

cleantrials_persess = reshape(cleantrials, [2 61])';
sj = mean(reshape(sj, [2 61])', 2);
enoughtrials_persess = cleantrials_persess > 100;
cleansj = all(enoughtrials_persess, 2);

fprintf('%d subjects with sufficient trials in both sessions \n', sum(cleansj));

cleansjnum = sj(cleansj)
badsjnum   = setdiff(sj, cleansjnum)

% THIS LIST GOES INTO SUBJECTSPECIFICS, 'clean'
% histogram(cleantrials, 30);
% xlabel('Number of trials after preproc');
% print(gcf, '-dpdf', sprintf('%s/Figures/cleantrials_distribution.pdf', subjectdata.path));

% ADD INFO ON CHOICE HISTORY
tab = alldat;
tab = tab(ismember(tab.subj_idx, cleansjnum), :);

% recode hands
tab.hand(tab.hand == 12) = -1;
tab.hand(tab.hand == 18) = 1;

% ADD SOME HISTORY VARS
tab.prev_stim     = circshift(tab.stimulus, 1);
tab.prev_resp     = circshift(tab.response, 1);
tab.prev_hand     = circshift(tab.hand, 1);

tab.prev2resp     = circshift(tab.response, 2);
tab.prev3resp     = circshift(tab.response, 3);
tab.prev4resp     = circshift(tab.response, 4);
tab.prev5resp     = circshift(tab.response, 5);
tab.prev6resp     = circshift(tab.response, 6);
tab.prev7resp     = circshift(tab.response, 7);

tab.prev1hand     = circshift(tab.hand, 1);
tab.prev2hand     = circshift(tab.hand, 2);
tab.prev3hand     = circshift(tab.hand, 3);
tab.prev4hand     = circshift(tab.hand, 4);
tab.prev5hand     = circshift(tab.hand, 5);
tab.prev6hand     = circshift(tab.hand, 6);
tab.prev7hand     = circshift(tab.hand, 7);

% code for previous reward too
tab.prev_correct  = circshift(tab.correct, 1);
tab.prevresp_correct = tab.prev_resp;
tab.prevresp_correct(tab.prev_correct == 0) = 0;
tab.prevresp_error = tab.prev_resp;
tab.prevresp_error(tab.prev_correct == 1) = 0;
assert(isequaln(tab.prevresp_correct + tab.prevresp_error, tab.prev_resp));
% tab.prev_correct(tab.prev_correct == 0) = -1; % effects coding
tab.prev_error = abs(tab.prev_correct - 1); % code for difference with prev error

% for contrast previous wrong answer only
tab.prev_wrong = tab.prev_error;
tab.prev_wrong(tab.prev_wrong == 0) = -1;

% same for the hand, motor coding
tab.prevhand_correct = tab.prev_hand;
tab.prevhand_correct(tab.prev_correct == 0) = 0;
tab.prevhand_error = tab.prev_hand;
tab.prevhand_error(tab.prev_correct == 1) = 0;
assert(isequaln(tab.prevhand_correct + tab.prevhand_error, tab.prev_hand));

% repetition or alternation
tab.repeat        = 1 * (tab.prev_resp == tab.response);
%tab.repeat(tab.repeat == 0) = -1; % to allow for the same coding as other vars
tab.stimrepeat        = 1 * (tab.stimulus == tab.prev_stim);
%tab.stimrepeat(tab.stimrepeat == 0) = -1; % to allow for the same coding as other vars


% remove for trials that are not continuous
wrongtrl          = (tab.trial ~= circshift(tab.trial, 1) + 1);
tab{wrongtrl, {'prev_stim', 'prev_resp', 'prev_hand', 'repeat', 'stimrepeat', ...
    'prev2resp', 'prev3resp', 'prev4resp', 'prev5resp', 'prev6resp', 'prev7resp'}} = nan;

%% =========================================== %
% determine group splits
% =========================================== %

[gr, repetition] = findgroups(tab(:, 'subj_idx'));
repetition.repeat = splitapply(@nanmean, tab.repeat, gr);

repetition.repeat_zscore = zscore(repetition.repeat);
for sj = unique(tab.subj_idx)'
    tab.repetition(tab.subj_idx == sj) = ...
        repetition.repeat(repetition.subj_idx == sj);
    tab.repetition_zscore(tab.subj_idx == sj) = ...
        repetition.repeat_zscore(repetition.subj_idx == sj);
end

% use all subjects, except P39 (exactly P(repeat) at 0.5)
tab.group = zeros(size(tab.repetition));
tab.group(tab.repetition < 0.5) = -1; % alternators
tab.group(tab.repetition > 0.5) = 1; % repeaters

% check: how many repeaters and alternators?
disp('group definition based on P(repeat):');
disp(hist(splitapply(@mean, tab.group, findgroups(tab.subj_idx))))
writetable(tab, sprintf('%s/allsubjects_meg.csv', allsubjectdata.csvdir));

