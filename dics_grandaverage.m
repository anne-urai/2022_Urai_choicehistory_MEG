function [] = dics_grandaverage(sessions, vs)
% select subsets of trials that we'll look at and compare,

if ~exist('sessions', 'var'), sessions = 1:2; end
if ischar(sessions),          sessions = str2double(sessions); end

freqs                         = dics_freqbands; % retrieve specifications
if ~exist('vs', 'var'),       vs = 1:length(freqs); end
if ischar(vs),                vs = str2double(vs); end

% define subjects
sjdat       = subjectspecifics('GA');
subjects    = sjdat.clean;
percchange = @(pow, bl) 100 .* (pow - bl) ./ bl;

% ==================================================================
% GRAND AVERAGE
% ==================================================================

for session = sessions,
    for v = vs,
        
        % ==================================================================
        % GATHER AND BASELINE CORRECT
        % ==================================================================
        
        clear source
        for sj = subjects,
            subjectdata = subjectspecifics(sj);
            
            file = sprintf('%s/P%02d-S%d_parcel_%s.mat', ...
                subjectdata.roidir, sj, session, freqs(v).name);
            
            if exist(file, 'file'),
                load(file); disp(file); 
                
                % DO BASELINE CORRECTION WITHIN EACH REGION AND PARTICIPANT
                % CONVERT TO PERCENT SIGNAL CHANGE
                catbl = squeeze(mean(mean(parcel.pow(:, :, 5:10), 2), 3));
                parcel.pow = bsxfun(percchange, parcel.pow, catbl);

                % MANUALLY APPEND
                if ~exist('source', 'var'),
                    source = parcel;
                else
                    source.pow = cat(2, source.pow, parcel.pow);
                    source.trialinfo = cat(1, source.trialinfo, parcel.trialinfo);
                end
            end
        end

        % ==================================================================
        % FOR MOTOR REGIONS, COMPUTE LATERALIZATION 
        % after baseline correction
        % ==================================================================
        
        regions         = source.label;
        left_regions    = regions(~cellfun('isempty', regexp(regions, 'left', 'match')));
        right_regions   = regexprep(left_regions, 'left', 'right');
        lateralization  = regexprep(left_regions, 'left', 'lateralized');
        
        disp('Computing lateralisation for motor regions...');
        for r = 1:length(left_regions),
            source.label(end+1) = lateralization(r);
            leftidx     = find(~cellfun(@isempty, regexp(regions, left_regions{r})));
            rightidx    = find(~cellfun(@isempty, regexp(regions, right_regions{r})));
            source.pow(end+1, :, :) = source.pow(leftidx, :, :) - source.pow(rightidx, :, :);
        end
        
        % reshape the dims to be easier to work with
        tic;
        savefast(sprintf('%s/GA-S%d_parcel_%s.mat', sjdat.roidir, ...
            session, freqs(v).name), 'source');
        toc;
        
        % ==================================================================
        % REDO WITHOUT BASELINE CORRECTION
        % ==================================================================
        
        clear source
        for sj = subjects,
            subjectdata = subjectspecifics(sj);
            
            file = sprintf('%s/P%02d-S%d_parcel_%s.mat', ...
                subjectdata.roidir, sj, session, freqs(v).name);
            
            if exist(file, 'file'),
                load(file); disp(file);
                
                % MANUALLY APPEND
                if ~exist('source', 'var'),
                    source = parcel;
                else
                    source.pow = cat(2, source.pow, parcel.pow);
                    source.trialinfo = cat(1, source.trialinfo, parcel.trialinfo);
                end
            end
        end
        
        % reshape the dims to be easier to work with
        tic;
        savefast(sprintf('%s/GA-S%d_parcel_noblcorr_%s.mat', sjdat.roidir, ...
            session, freqs(v).name), 'source');
        toc;
    end
end

end
