function [] = mri_makeHeadmodel(subjects)
% make single-sphere headmodels from individual MRI
% run this on UKE cluster

if ~isdeployed,
    addpath('~/code/MEG');
    addpath(genpath('~/code/Tools'));
    addpath('~/Documents/fieldtrip');
    ft_defaults;  % ft_defaults should work in deployed app?
    close all; warning off;
else
    addpath('~/Documents/fieldtrip');
    ft_defaults;  % ft_defaults should work in deployed app?
    warning off;
end

% for running on stopos
if ~exist('subjects', 'var'),
    subjectdata = subjectspecifics('GAall');
    subjects    = subjectdata.clean;
end

% for stopos
if ischar(subjects), subjects = str2double(subjects); end

for sj = subjects,
    tic;
    subjectdata = subjectspecifics(sj);
    
    % ==================================================================
    % PREPARE HEADMODEL
    % ==================================================================
    
    % if ~exist(sprintf('%s/P%02d_mri.mat', subjectdata.mridir, sj), 'file'),
    
    % V2 has the fiducials already placed at lpa, rpa, nasion
    mrifiles = dir([subjectdata.mridir '/*_V2.mri']);
    mrifile  = sprintf('%s/%s', subjectdata.mridir, mrifiles.name);
    
    % read in the individual
    disp(mrifile);
    mri                     = ft_read_mri(mrifile);
    
    % reslice to isotropic voxels
    cfg                     = [];
    cfg.resolution          = 1; % 1 mm
    mri                     = ft_volumereslice(cfg, mri);
    mri                     = ft_convert_units(mri, 'cm');
    
    % ==================================================================
    % segment the volume, this takes longest
    % ==================================================================
    
    cfg                     = [];
    cfg.output              = {'tpm'}; % brain or white/gray/csf separately?
    cfg.spmversion          = 'spm12';
    cfg.spmmethod           = 'old';
    segmentedmri            = ft_volumesegment(cfg, mri);
    segmentedmri.anatomy    = mri.anatomy; % keep this in
    
    savefast(sprintf('%s/P%02d_mri.mat', subjectdata.mridir, sj), ...
        'mri', 'segmentedmri');
    %   else
    %     load(sprintf('%s/P%02d_mri.mat', subjectdata.mridir, sj));
    %  end
    
    % plot on top to check brain is in the right place
    close all;
    ft_sourceplot(struct('funparameter', 'gray', 'location', 'center', ...
        'interactive', 'no', 'renderer', 'zbuffer'), segmentedmri);
    drawnow; pause(0.1);
    export_fig(gcf, sprintf('%s/P%02d_mrisegment.png', subjectdata.figsdir, sj));
    
    % ==================================================================
    % prepare headmodel
    % ==================================================================
    
    cfg                 = [];
    cfg.method          = 'singleshell'; % Guido's method
    headmodel           = ft_prepare_headmodel(cfg, segmentedmri);
    
    % check if the head model is aligned with grad struct
    load(sprintf('%s/P%02d-S%d_cleandata.mat', ...
        subjectdata.preprocdir, sj, 1 ));
    
    close all;
    hold on
    ft_plot_headmodel(headmodel, 'facealpha', 0.5)
    ft_plot_sens(data.grad_avg, 'elecsize', 40, 'edgecolor', 'b');
    view(18, 5);
    export_fig(gcf, sprintf('%s/P%02d_headmodel.png', subjectdata.figsdir, sj));
    
    % ==================================================================
    % create the subject specific grid
    % warp the individual positions to MNI space
    % ==================================================================
    
    disp('making individual grid');
    cfg                     = [];
    cfg.mri                 = mri;
    cfg.warpmni             = 'yes';
    cfg.resolution          = 4; % 4mm spacing
    cfg.nonlinear           = 'yes'; % from Joram
    sourcemodel             = ft_prepare_sourcemodel(cfg);
    
    % plot the mesh that was created within the brain
    close all;
    hold on
    ft_plot_headmodel(headmodel, 'facealpha', 0.5)
    % ft_plot_sens(data.grad_avg, 'elecsize', 40, 'edgecolor', 'b');
    ft_plot_mesh(sourcemodel.pos(sourcemodel.inside,:), 'vertexsize', 1, 'vertexcolor', 'red');
    view(18, 5);
    export_fig(gcf, sprintf('%s/P%02d_sourcemodel.png', subjectdata.figsdir, sj));
    
    % save to disk
    savefast(sprintf('%s/P%02d_headmodel.mat', subjectdata.mridir, sj), ...
        'headmodel', 'sourcemodel');
    fprintf('%s/P%02d_headmodel.mat \n', subjectdata.mridir, sj);
    
    toc;
end % subjects
end % function
