function [newdata] = getData_ERF(sj, session, name, group, chans)
% call for plotting or stats

switch group
    case 'lateralisation',

        % get data recursively
        newdata = getData_ERF(sj, session, name, 'tmp');

        for n = 1:length(name),
            % create virtual sensor
            newdata(n).label{end+1} = 'lat';
            changroup = find(~cellfun(@isempty, (strfind({chans(:).group}, group))));

            if isnumeric(sj),
                % add avg over chans within this sj
                newdata(n).avg(end+1, :) = ...
                    squeeze(mean(newdata(n).avg(chans(changroup).rightchans.sens, :), 1)) - ...
                    squeeze(mean(newdata(n).avg(chans(changroup).leftchans.sens, :), 1));
                % show error bars for individual sj
                newdata(n).sem(end+1, :) = nan(size(newdata(n).avg(end, :)));
            else
                % add avg and sem
                newdata(n).avg(:, end+1, :) = ...
                    squeeze(mean(newdata(n).avg(:, chans(changroup).rightchans.sens, :), 2)) - ...
                    squeeze(mean(newdata(n).avg(:, chans(changroup).leftchans.sens, :), 2));
            end
        end

    otherwise

        % proceed with normal data loading
        subjectdata = subjectspecifics(sj);

        for n = 1:length(name),

            % load in the right files
            locks = {'ref', 'stim', 'resp', 'fb'};
            for l = 1:length(locks),
                if isnumeric(sj),
                    load(sprintf('%s/P%02d-S%d_bl_%s_%s.mat', ...
                        subjectdata.lockdir, sj, session, locks{l}, name{n}));
                    switch group
                    case {'POz', 'POz_unfiltered'}
                            data.avg         = data.avg .* 1e6; % mV
                        otherwise
                            data.avg         = data.avg .* 1e12; % pT
                    end
                    ldata{l}         = data;

                else % GA
                    load(sprintf('%s/%s-S%d_lockbl_%s_%s.mat', ...
                        subjectdata.lockdir, sj, session, locks{l}, name{n}));

                    % change into pT
                    switch group
                        case 'POz' % microVolt
                            grandavg.individual = grandavg.individual * 1e6;
                        otherwise % picoTesla
                            grandavg.individual = grandavg.individual * 1e12;
                    end
                    ldata{l}            = grandavg;
                end
            end

            if isnumeric(sj),
                newdata(n).avg      = cat(2, ...
                    squeeze(ldata{1}.avg), ...
                    squeeze(ldata{2}.avg), ...
                    squeeze(ldata{3}.avg), ...
                    squeeze(ldata{4}.avg));
                newdata(n).dimord     = 'chan_time';
                newdata(n).sem      = nan(size(newdata(n).avg));
                newdata(n).grad     = ldata{1}.grad;
                newdata(n).label    = ldata{1}.label;
                newdata(n).timename  = [ldata{1}.time ldata{2}.time ldata{3}.time ldata{4}.time];

                % fool fieldtrip into thinking that the time axis increases
                newdata(n).time       = 1:length(newdata(n).timename);

                try
                    newdata(n).fsample  = ldata{1}.fsample;
                catch
                    newdata(n).fsample = 400;
                    warning('no sample rate found, using 400 Hz');
                end

                % BASELINE CORRECTION
                megchans    = find(strncmp(newdata(n).label, 'M', 1));
                blsmp       = [dsearchn(ldata{1}.time', -0.49): dsearchn(ldata{1}.time', 0)];
                bl          = mean(newdata(n).avg(megchans, blsmp), 2);
                newdata(n).avg(megchans, :) = bsxfun(@minus, newdata(n).avg(megchans, :), bl);

            else
                newdata(n).avg      = cat(3, ...
                    squeeze(ldata{1}.individual), ...
                    squeeze(ldata{2}.individual), ...
                    squeeze(ldata{3}.individual), ...
                    squeeze(ldata{4}.individual));
                newdata(n).dimord     = 'subj_chan_time';
                newdata(n).fsample = unique(round(1./diff(ldata{1}.time)));


                newdata(n).label     = ldata{1}.label;
                newdata(n).timename  = [ldata{1}.time ldata{2}.time ldata{3}.time ldata{4}.time];

                % fool fieldtrip into thinking that the time axis increases
                newdata(n).time       = 1:length(newdata(n).timename);

                % baseline correction
                megchans    = find(strncmp(newdata(n).label, 'M', 1));
                blsmp       = [dsearchn(ldata{1}.time', -0.3):dsearchn(ldata{1}.time', 0)];
                % one baseline for every participant and channel
                bl          = mean(newdata(n).avg(:, megchans, blsmp), 3);
                newdata(n).avg(:, megchans, :) = bsxfun(@minus, newdata(n).avg(:, megchans, :), bl);
            end % sj vs grandavg
        end
end
end
