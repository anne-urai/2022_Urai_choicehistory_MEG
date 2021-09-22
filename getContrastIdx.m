function [trls, name] = getContrastIdx(trl, whichContrast)
% get the trl indices for all groups of trials

% in case we just want the names
if isempty(trl), trl = nan(1, 18);
    % disp('empty trl, filling with NaNs');
    t = array2table(nan(1, 2), 'variablenames', {'resp', 'prev_resp'});
end

% GRAB THE BIG CSV FILE
subjectdata     = subjectspecifics('GA');
t               = readtable(sprintf('%s/CSV/allsubjects_meg.csv', subjectdata.path));
t.prev_hand     = circshift(t.hand, 1);
t.prev_resp     = circshift(t.response, 1);

% map table idx to MEG idx
[~, ~, tidx]    = intersect(trl(:, 18), t.idx);
t               = t(tidx, :); % keep only that part of the table

% NOW SELECT TRIALS
switch whichContrast
    case 1
        trls = find(~isnan(t.rt)); % all trials
        name = 'all';
    case 2
        trls = find(t.stimulus == -1);
        name = 'stimweak';
    case 3
        trls = find(t.stimulus == -1 & t.response == -1);
        name = 'stimweak_respweak';
    case 4
        trls = find(t.stimulus == -1 & t.response == 1);
        name = 'stimweak_respstrong';
    case 5
        trls = find(t.stimulus == 1);
        name = 'stimstrong';
    case 6
        trls = find(t.stimulus == 1 & t.response == 1);
        name = 'stimstrong_respstrong';
    case 7
        trls = find(t.stimulus == 1 & t.response == -1);
        name = 'stimstrong_respweak';
    case 8
        trls = find(t.response == -1);
        name = 'respweak';
    case 9
        trls = find(t.response == 1);
        name = 'respstrong';
    case 10
        trls = find(t.correct == 1);
        name = 'correct';
    case 11
        trls = find(t.correct == 0);
        name = 'error';
    case 12
        trls = find(t.hand == 12);
        name = 'left';
    case 13
        trls = find(t.hand == 18);
        name = 'right';
    case 14
        trls = find(t.hand == 12 & t.correct == 1);
        name = 'left_correct';
    case 15
        trls = find(t.hand == 18 & t.correct == 1);
        name = 'right_correct';
    case 16
        trls = find(t.hand == 12 & t.correct == 0);
        name = 'left_error';
    case 17
        trls = find(t.hand == 18 & t.correct == 0);
        name = 'right_error';
    case 18
        medRT = median(t.rt);
        trls = find(t.correct == 1 & t.rt > medRT);
        name = 'correct_slow';
    case 19
        medRT = median(t.rt);
        trls = find(t.correct == 1 & t.rt < medRT);
        name = 'correct_fast';
    case 20
        trls = find(t.prev_hand == 12);
        name = 'prev_left';
    case 21
        trls = find(t.prev_hand == 18);
        name = 'prev_right';
    case 22
        trls = find(t.prev_resp == -1);
        name = 'prev_respweak';
    case 23
        trls = find(t.prev_resp == 1);
        name = 'prev_respstrong';
    case 24
        trls = find(t.response == t.prev_resp);
        name = 'repetition';
    case 25
        trls = find(t.response ~= t.prev_resp);
        name = 'alternation';
    case 26
        if ismember(unique(t.subj_idx), subjectdata.alternators),
            trls = find(t.response ~= t.prev_resp);
        elseif ismember(unique(t.subj_idx), subjectdata.repeaters),
            trls = find(t.response == t.prev_resp);
        else 
            trls = [];
        end
        name = 'preferred';
    case 27
        if ismember(unique(t.subj_idx), subjectdata.alternators),
            trls = find(t.response == t.prev_resp);
        elseif ismember(unique(t.subj_idx), subjectdata.repeaters),
            trls = find(t.response ~= t.prev_resp);
        else
            trls = [];
        end
        name = 'nonpreferred';
    case 28
        trls = find(t.response ~= t.prev_resp & t.hand == 12);
        name = 'alternation_left';
    case 29
        trls = find(t.response == t.prev_resp & t.hand == 12);
        name = 'repetition_left';
    case 30
        trls = find(t.response ~= t.prev_resp & t.hand == 18);
        name = 'alternation_right';
    case 31
        trls = find(t.response == t.prev_resp & t.hand == 18);
        name = 'repetition_right';
end

if ~exist('trls', 'var'), trls = NaN; end

end
