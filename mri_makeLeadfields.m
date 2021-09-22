function [] = mri_makeLeadfields(subjects)

if ~isdeployed,
    addpath('~/code/MEG');
    addpath(genpath('~/code/Tools'));
    addpath('~/Documents/fieldtrip');
    ft_defaults;  % ft_defaults should work in deployed app?
    close all; warning off;
end

% for running on stopos
if ~exist('subjects', 'var'),
    subjectdata = subjectspecifics('GAall');
    subjects    = subjectdata.clean;
end
if ischar(subjects), subjects = str2double(subjects); end

grad_options = {'first', 'avg'};
for go = 1:2,
whichgrad = grad_options{go};

    for sj = subjects,
        
        subjectdata = subjectspecifics(sj);
        load(sprintf('%s/P%02d_headmodel.mat', subjectdata.mridir, sj));
        
        % ==================================================================
        % PREPARE LEADFIELDS BASED ON GRAD DEFINITION FOR THIS FILE
        % ==================================================================
        
        for session = [1 2],
            
            % load the last recording for chanpos
            load(sprintf('%s/P%02d-S%d_cleandata.mat', subjectdata.preprocdir, sj, session));

            switch whichgrad
                case 'first'
                    grad = data.grad_first;
                case 'avg'
                    grad = data.grad_avg;
            end
            
            % make sure to exclude missing sensors
            cfg                     = [];
            cfg.grad                = grad;         % gradiometers specific to this recording
            cfg.headmodel           = headmodel;    % predefined gridpoints based on MRI
            cfg.sourcemodel         = sourcemodel;  % source model without leadfields
            cfg.channel             = ft_channelselection('MEG', data.label);      % remove those which are missing
            cfg.reducerank          = 2;            % whats a good default here?
            cfg.feedback            = 'none';       % improve readability of logfiles
            cfg.normalize           = 'yes';        % to remove depth bias (Q in eq. 27 of van Veen et al, 1997)
            
            leadfield               = ft_prepare_leadfield(cfg);
            leadfield               = rmfield(leadfield, 'cfg');

            save(sprintf('%s/P%02d-S%d_leadfields_%sgrad.mat', ...
                subjectdata.mridir, sj, session, whichgrad), 'leadfield', '-v7.3');
            fprintf('%s/P%02d-S%d_leadfields_%sgrad.mat \n', ...
                subjectdata.mridir, sj, session, whichgrad);
            
        end % session
    end % subjects
end % grad struct options

end % function
