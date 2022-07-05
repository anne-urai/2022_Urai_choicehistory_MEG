function [] = mri_templateMRI
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

subjectdata = subjectspecifics('GA');

% ==================================================================
% dont do this myself but use FieldTrip's templates
% ==================================================================

load('~/Documents/fieldtrip/template/headmodel/standard_mri.mat');
template_mri = mri;
savefast(sprintf('%s/template_mri.mat', subjectdata.mridir), 'template_mri');

% ==================================================================
% possible templates:
% SPM T1, colin27 (copied from fieldtrip/template/anatomy)
% http://www.fieldtriptoolbox.org/template/anatomy
% see http://www.fieldtriptoolbox.org/tutorial/sourcemodel#subject-specific_grids_that_are_equivalent_across_subjects_in_normalized_space
% for how to make my own sourcemodel
% ==================================================================
%
%     mrifile     = dir(sprintf('%s/%s', subjectdata.mridir, '*.nii'));
%
%     if exist(sprintf('%s/template_mri.mat', subjectdata.mridir), 'file'),
%         load(sprintf('%s/template_mri.mat', subjectdata.mridir));
%     else
%         % read in the individual
%         disp(mrifile);
%         template_mri            = ft_read_mri(sprintf('%s/%s', subjectdata.mridir, mrifile.name));
%         template_mri.coordsys   = 'mni';

% reslice to isotropic voxels
cfg                     = [];
cfg.resolution          = 1; % 1 mm
template_mri            = ft_volumereslice(cfg, template_mri);
template_mri            = ft_convert_units(template_mri, 'cm');

% ==================================================================
% segment the volume, this takes longest
% ==================================================================

cfg                             = [];
cfg.output                      = {'brain'}; % brain or white/gray/csf separately?
cfg.spmversion                  = 'spm12';
cfg.spmmethod                   = 'old';
template_segmentedmri           = ft_volumesegment(cfg, template_mri);
template_segmentedmri.anatomy   = template_mri.anatomy; % keep this in
savefast(sprintf('%s/template_mri.mat', subjectdata.mridir), 'template_mri', 'template_segmentedmri');

% plot on top to check brain is in the right place
ft_sourceplot(struct('funparameter', 'brain', 'location', 'center', ...
    'interactive', 'no', 'renderer', 'zbuffer'), template_segmentedmri);
%suplabel(mrifile.name, 't');
export_fig(gcf, '-r1000', sprintf('%s/Template_mrisegment_brain.png', subjectdata.mridir));

% ==================================================================
% prepare headmodel
% ==================================================================

cfg                   = [];
cfg.method            = 'singleshell'; % Guido's method
cfg.tissue            = 'brain';
template_headmodel    = ft_prepare_headmodel(cfg, template_segmentedmri);

% ==================================================================
% CREATE A SOURCE MODEL WITH SUFFICIENT RESOLUTION
% ==================================================================

cfg                     = [];
cfg.headmodel           = template_headmodel; % has the brain surface which is what we want to use
cfg.grid.resolution     = 0.5; % need 4 mm max, otherwise no FEF defined in Wang atlas (see email 6 July 2017)
cfg.grid.unit           = 'cm';
cfg.grid.tight          = 'yes';
cfg.inwardshift         = -1;  % from Joram
template_sourcemodel    = ft_prepare_sourcemodel(cfg);

% save to disk
savefast(sprintf('%s/template_headmodel.mat', subjectdata.mridir), 'template_headmodel', 'template_sourcemodel');

% plot the mesh that was created
close all;
ft_plot_mesh(template_sourcemodel.pos(template_sourcemodel.inside,:));
ft_plot_vol(template_headmodel, 'facecolor', 'skin', 'edgecolor', 'none', 'surfaceonly', 1);
view(-105, 13); % orient so the reference channels are visible on the top
%title(mrifile.name, 'interpreter', 'none');
export_fig(gcf,  '-r1000', sprintf('%s/Template_sourcemodel.png', subjectdata.mridir));
savefig(gcf, sprintf('%s/Template_sourcemodel.fig', subjectdata.mridir));
savefast(sprintf('%s/template_sourcemodel.mat', subjectdata.mridir), 'template_sourcemodel');

end
