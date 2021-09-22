function [newdata] = getData_TFR(sj, session, name, group, chans, ei)
% call for plotting or stats

switch group
    case 'lateralisation',

        % get data recursively
        newdata = getData_TFR(sj, session, name, 'tmp', chans, ei);

        for n = 1:length(name),
            
            % create virtual sensor
            newdata(n).label{end+1} = 'lat';
            changroup = find(~cellfun(@isempty, (strfind({chans(:).group}, group))));
            
            newdata(n).powspctrm(end+1, :, :) = ...
                squeeze(mean(newdata(n).powspctrm(chans(changroup).rightchans.sens, :, :), 1)) - ...
                squeeze(mean(newdata(n).powspctrm(chans(changroup).leftchans.sens, :, :), 1));
            
        end

    otherwise

        subjectdata = subjectspecifics(sj);

        for n = 1:length(name),
            % load in the right file
            locks = {'ref', 'stim', 'resp', 'fb'};

            for l = 1:length(locks),
                if isnumeric(sj),
                    switch ei
                        case 'evoked'
                            load(sprintf('%s/P%02d-S%d_evoked_bl_%s_%s.mat', ...
                                subjectdata.tfrdir, sj, session, locks{l}, name{n}));
                        case 'induced'
                            load(sprintf('%s/P%02d-S%d_bl_%s_%s.mat', ...
                                subjectdata.tfrdir, sj, session, locks{l}, name{n}));
                    end
                    if ndims(freq.powspctrm) < 4,
                        freq.powspctrm   = permute(freq.powspctrm, [4 1 2 3]); % add subj di
                    end
                    ldata{l}         = freq;
                else
                    switch ei
                        case 'evoked'
                            load(sprintf('%s/%s-S%d_evoked_freqbl_%s_%s.mat', ...
                                subjectdata.tfrdir, sj, session, locks{l}, name{n}));

                        case 'induced'
                            load(sprintf('%s/%s-S%d_freqbl_%s_%s.mat', ...
                                subjectdata.tfrdir, sj, session, locks{l}, name{n}));
                    end
                    ldata{l} = grandavg;
                end
            end

            newdata(n).label    = ldata{1}.label;
            newdata(n).freq     = ldata{1}.freq;
            newdata(n).powspctrm      = squeeze(cat(ndims(ldata{1}.powspctrm), ...
                ldata{1}.powspctrm, ...
                ldata{2}.powspctrm, ...
                ldata{3}.powspctrm, ...
                ldata{4}.powspctrm));
            newdata(n).timename  = [ldata{1}.time ldata{2}.time ldata{3}.time ldata{4}.time];

            % fool fieldtrip into thinking that the time axis increases
            newdata(n).time       = 1:length(newdata(n).timename);
            newdata(n).fsample    = 1./ unique(round(diff(ldata{1}.time), 3)); % time steps
            
            if isnumeric(sj) || ndims(newdata(n).powspctrm) == 3,
                newdata(n).dimord     = 'chan_freq_time';
            else
                newdata(n).dimord     = 'subj_chan_freq_time';
            end
            
            
        end

end
end
