% DO THE ACTUAL BEAMFORMER OVER TIMEPOINTS
allsubjectdata = subjectspecifics('ga');
subjects       = allsubjectdata.all;
subjects       = allsubjectdata.clean;

% ALL SESSIONS
paramsA      = [];
for sj = subjects,
    subjectdata = subjectspecifics(sj);
    for session = 1:2,
        for v = 3, % alpha
            for l = 1:4,
                paramsA = [paramsA; sj session v l];
            end
        end
    end
end
dlmwrite('stopos/params_dics', paramsA, 'delimiter', ' ');

size(paramsA)


% % SESSION ZERO
% paramsA      = [];
% for sj = subjects,
%     subjectdata = subjectspecifics(sj);
%     paramsA = [paramsA; sj 0];
% end
% dlmwrite('stopos/params_sessions_zero', paramsA, 'delimiter', ' ');

% %%%%
% paramsA      = [];
% for sj = subjects,
%     for session = 0,
%         for f = 3:6,
%             for l = 1:4,
%                 paramsA = [paramsA; sj session f 1 l];
%             end
%         end
%     end
% end
% dlmwrite('stopos/params_b8b', paramsA, 'delimiter', ' ');
