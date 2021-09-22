function dics_parcellate(sj, sessions, vs)

% ==================================================================
% LOAD IN SUBJECT SPECIFICS AND READ DATA
% ==================================================================

if ischar(sj), sj = str2double(sj); end
subjectdata = subjectspecifics(sj);

if ~exist('sessions', 'var'), sessions = [1:length(subjectdata.session)]; end
if ischar(sessions), sessions = str2double(sessions); end

freqs  = dics_freqbands; % retrieve specifications
if ~exist('vs', 'var'), sessions = [1:length(freqs)]; end
if ischar(vs), vs = str2double(vs); end

% LOAD PRE-DEFINED ATLASES
atlases = load(sprintf('%s/GrandAverage/MRI/atlas_rois_clusters.mat', subjectdata.path));
atlases = atlases.atlases;
atl_names = cellfun(@(x) x.name, atlases, 'UniformOutput', false);

% only do the parcellation for some atlases so that the files don't explode
atlases_2parc = find(ismember(atl_names, {'wang_vfc_lat', 'wang_vfc',  ...
    'jwg', 'jwg_symm', 'glasser_premotor', 'glasser_premotor_symm'}));
for a = atlases_2parc,
    disp(atlases{a}.name);
    disp(atlases{a}.tissuelabel');
end
expected_tissues = cat(1, atlases{a}.tissuelabel');
disp(expected_tissues);

% ==================================================================
% PARCELLATE
% ==================================================================

for session = sessions,
    for v = vs, % frequency bands

        % DON'T REDO IF ALREADY COMPLETED
        if exist(sprintf('%s/P%02d-S%d_parcel_%s.mat', ...
            subjectdata.roidir, sj, session, freqs(v).name), 'file')
            % continue; % skip if done already
        end

        % LOOP OVER TRIAL EPOCHS
        lockings = {'ref', 'stim', 'resp', 'fb'};
        for l = 1:length(lockings),
            
            source_l = load(sprintf('%s/P%02d-S%d_dics_%s_%s.mat', ...
                subjectdata.sourcedir, sj, session, freqs(v).name, lockings{l}));
            fprintf('%s/P%02d-S%d_dics_%s_%s.mat \n', ...
                subjectdata.sourcedir, sj, session, freqs(v).name, lockings{l});

            % skip full glasser atlas for now; too many points
            for a = atlases_2parc,
                
                % give pos to the atlas, otherwise this won't work
                atlases{a}.pos   = source_l.source.pos;
                
                % parcellate using the mean across gridpoints for each ROI
                parcellated_tmp       = ft_sourceparcellate(struct('parameter', 'pow'), source_l.source, atlases{a});

                % append across atlases
                if a == atlases_2parc(1),
                    parcellated_l        = rmfield(parcellated_tmp, {'cfg', 'brainordinate'});
                    parcellated_l.label  = strcat(atlases{a}.name, '_', parcellated_tmp.label');
                    parcellated_l.time   = source_l.source.time; % keep time in each lock
                else,
                    % append to existing structure
                    parcellated_l.label  = cat(1, parcellated_l.label, strcat(atlases{a}.name, '_', parcellated_tmp.label'));
                    parcellated_l.pow    = cat(1, parcellated_l.pow, parcellated_tmp.pow);
                end
                
            end
            
            % ==================================================================
            % APPEND ACROSS LOCKINGS
            % ==================================================================
            
            if l == 1,
                parcel      = parcellated_l;
            else
                % ADD 3 TIMEBINS WITH NANS FOR EASIER PLOTTING - 
                % TO DISTINGUISH DIFFERENT ASK EPOCHS
                assert(isequal(parcel.label, parcellated_l.label), 'ROI labels should match across lockings');
                parcel.time = cat(2, parcel.time, nan(1, 3), parcellated_l.time);
                parcel.pow  = cat(3, parcel.pow, nan(size(parcel.pow, 1), size(parcel.pow, 2), 3), parcellated_l.pow);
            end
        end
        
        % ADD TRIALINFO BACK IN if it's missing
        if ~isfield(parcel, 'trialinfo'),
            disp('adding trialinfo back from cleandata file');
            data = load(sprintf('%s/P%02d-S%d_cleandata.mat', ...
                subjectdata.preprocdir, sj, session));
            parcel.trialinfo = data.data.trialinfo;
            clear data;
        end
        
        disp(parcel);
        disp(parcel.label);
        warning('expected %d areas, found %s', length(expected_tissues), ...
            length(parcel.label));

        % ==================================================================
        % SAVE
        % ==================================================================
        
        savefast(sprintf('%s/P%02d-S%d_parcel_%s.mat', ...
            subjectdata.roidir, sj, session, freqs(v).name), 'parcel');
        fprintf('\nSAVED %s/P%02d-S%d_parcel_%s.mat \n', ...
            subjectdata.roidir, sj, session, freqs(v).name);
        
    end
end

end