function preproc_writeCSV()

if ~isdeployed,
    addpath(genpath('~/code/MEG'));
    addpath(genpath('~/code/Tools'));
    addpath('~/Documents/fieldtrip');
    ft_defaults;
    warning off; % lots of FT crap
end

allsubjectdata = subjectspecifics('ga');
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

%% DETERMINE WHICH SUBJECTS ARE CLEAN
alldat   = readtable(sprintf('%s/allsubjects_meg.csv', allsubjectdata.csvdir));
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
