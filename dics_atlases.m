function dics_atlases()

% ==================================================================
% LOAD AND INTERPOLATE ATLASES
% ==================================================================

template_sourcemodel = load('~/Documents/fieldtrip/template/sourcemodel/standard_sourcemodel3d4mm.mat');
subjectdata = subjectspecifics('GA');
plot_me = true;
if plot_me, set(groot, 'DefaultFigureWindowStyle','normal'); end

% ==================================================================
% GLASSER ET AL. 2016
% see https://github.com/DonnerLab/pymeg/blob/master/pymeg/atlas_glasser.py
% for region names
% ==================================================================

glasser             = load(sprintf('%s/atlas_MMP1.0_4k.mat', subjectdata.mridir));
atlas               = ft_convert_units(glasser.atlas, 'cm');
cfg                 = [];
cfg.parameter       = 'parcellation';
atlas2              = ft_sourceinterpolate(cfg, rmfield(atlas, 'rgba'), template_sourcemodel.sourcemodel);
atlas2.tissue       = atlas2.parcellation;
atlas2.tissuelabel  = atlas.parcellationlabel';
atlas2              = rmfield(atlas2, {'parcellation', 'cfg'});
atlas2.name         = 'glasser';
atlases{1}          = atlas2;

% cluster glasser regions, according to:
% https://github.com/DonnerLab/pymeg/blob/master/pymeg/atlas_glasser.py#L287
atlases{end+1}      = cluster_rois(atlas2, get_clusters_glasser(0));
atlases{end}.name   = 'glasser_clust';

% only use premotor
atlases{end+1}      = atlases{end};
pmdv = find(strcmp(atlases{end}.tissuelabel, 'PMd/v'));
atlases{end}.tissuelabel = atlases{end}.tissuelabel(pmdv);
atlases{end}.tissue = double(atlases{end}.tissue == pmdv);
atlases{end}.name   = 'glasser_premotor_symm';

% as well as the lateralized version, left and right separately
atlases{end+1}      = cluster_rois(atlas2, get_clusters_glasser(1));
atlases{end}.name   = 'glasser_clust_lr';

% only use premotor
atlases{end+1}      = atlases{end};
pmdv = find(strcmp(atlases{end}.tissuelabel, 'left_PMd/v'));
newtissuelabel = atlases{end}.tissuelabel(pmdv);
newtissue = double(atlases{end}.tissue == pmdv);

pmdv = find(strcmp(atlases{end}.tissuelabel, 'right_PMd/v'));
newtissuelabel = [newtissuelabel atlases{end}.tissuelabel(pmdv)];
newtissue = newtissue + 2*double(atlases{end}.tissue == pmdv);
atlases{end}.tissue = newtissue;
atlases{end}.tissuelabel = newtissuelabel;
atlases{end}.name   = 'glasser_premotor';

% ==================================================================
% WANG ET AL. 2015
% from fieldtrip atlas file
% ==================================================================

atl                 = ft_read_atlas('~/Documents/fieldtrip/template/atlas/vtpm/vtpm.mat');
atl                 = ft_convert_units(atl, 'cm');

% interpolate to standard sourcemodel
cfg                 = [];
cfg.interpmethod    = 'nearest';
cfg.parameter       = 'tissue';
atl                 = ft_sourceinterpolate(cfg, atl, template_sourcemodel.sourcemodel);
atl                 = rmfield(atl, 'cfg');
atl.name            = 'wang';
atlases{end+1}      = atl;

% group left and right tissue indices; symmetrical
atl_symm            = group_leftright(atl);
atlases{end+1}      = atl_symm;
atlases{end}.name   = 'wang_symm';
 
% cluster according to:
% https://github.com/DonnerLab/pymeg/blob/master/pymeg/atlas_glasser.py#L228
atlases{end+1}      = cluster_rois(atl, get_clusters_wang2(0));
atlases{end}.name   = 'wang_vfc';

atlases{end+1}      = cluster_rois(atl, get_clusters_wang2(1));
atlases{end}.name   = 'wang_vfc_lat';

% ==================================================================
% motor regions, defined in MNI coordinates
% ==================================================================

% grab the glasser atlas to find the hand-defined coordinates
glasser                 = load(sprintf('%s/atlas_MMP1.0_4k.mat', subjectdata.mridir));
atlas_mnicoords         = ft_convert_units(glasser.atlas, 'cm');
atlas_mnicoords.tissue  = zeros(size(atlas_mnicoords.parcellation));
atlas_mnicoords         = rmfield(atlas_mnicoords, {'parcellationlabel', 'parcellation', 'rgba'});
motor_regions           = get_clusters_motorcoords;

% now, based on these MNI coordinates find the
% corresponding voxel in the uninterpolated source space
% see https://mailman.science.ru.nl/pipermail/fieldtrip/2014-March/007672.html
for r = 1:length(motor_regions.roi_labels), % go through each label
    atlas_mnicoords.tissuelabel{r} = motor_regions.roi_labels{r};
    mnicoord = motor_regions.mnicoords{r};
    for ii = 1:size(mnicoord, 1)
        idx = dsearchn(atlas_mnicoords.pos, mnicoord(ii, :));
        disp(motor_regions.roi_labels{r});
        disp(mnicoord); disp(atlas_mnicoords.pos(idx, :));
        atlas_mnicoords.tissue(idx) = r;
    end
end

% NOW INTERPOLATE TO TEMPLATE SOURCEMODEL
atlas2              = ft_sourceinterpolate(struct('parameter', 'tissue'),  ...
    atlas_mnicoords, template_sourcemodel.sourcemodel);
atlas2              = rmfield(atlas2, {'cfg'});
atlas2.tissuelabel  = motor_regions.roi_labels;
atlas2.name         = 'aeu';
atlases{end+1}      = atlas2;

% ADD SYMMETRICAL REGIONS, NOT LATERALIZED
atlases{end+1}      = group_leftright(atlas2);
atlases{end}.name   = 'aeu_symm';

% ==================================================================
% de Gee et al. 2017 (see also Wilming et al. 2020)
% M1, aIPS, IPS/PostCeS
% ==================================================================

% 1. LEFT HEMISPHERE
% atl_lh              = ft_read_atlas({sprintf('%s/JW_mriLabels/fsaverage/label/lh.JWG_lat.annot', subjectdata.mridir), ...
%     sprintf('%s/JW_mriLabels/fsaverage/label/lh.wang2015_atlas.mgz', subjectdata.mridir)}, 'format', 'freesurfer_aparc');

atl_lh = ft_read_atlas({sprintf('%s/JW_mriLabels/fsaverage/label/lh.JWG_lat.annot', subjectdata.mridir), ...
    sprintf('%s/JW_mriLabels/fsaverage/surf/lh.inflated', subjectdata.mridir)}, ...
    'units', 'cm', 'format', 'freesurfer_aparc');

% remove the unknown tissue; not included in this atlas
atl_lh.aparc = atl_lh.aparc - 1;
atl_lh.aparclabel(1) = [];

atl_lh                 = ft_convert_units(atl_lh, 'cm');
cfg                    = [];
cfg.interpmethod       = 'nearest';
cfg.parameter          = 'aparc';
atl_lh                 = ft_sourceinterpolate(cfg, atl_lh, template_sourcemodel.sourcemodel);
atl_lh.tissue          = atl_lh.aparc;
atl_lh.tissuelabel     = atl_lh.aparclabel';
for t = 1:length(atl_lh.tissuelabel),
    atl_lh.tissuelabel{t} = [atl_lh.tissuelabel{t} '_left'];
end
atl_lh.name ='jwg_lh';
atlases{end+1} = atl_lh;

% and right hemisphere
atl_rh = ft_read_atlas({sprintf('%s/JW_mriLabels/fsaverage/label/rh.JWG_lat.annot', subjectdata.mridir), ...
    sprintf('%s/JW_mriLabels/fsaverage/surf/rh.inflated', subjectdata.mridir)}, ...
    'units', 'cm', 'format', 'freesurfer_aparc');
atl_rh.aparc = atl_rh.aparc - 1;
atl_rh.aparclabel(1) = [];

atl_rh                 = ft_convert_units(atl_rh, 'cm');
cfg                    = [];
cfg.interpmethod       = 'nearest';
cfg.parameter          = 'aparc';
atl_rh                 = ft_sourceinterpolate(cfg, atl_rh, template_sourcemodel.sourcemodel);
atl_rh.tissue          = atl_rh.aparc;
atl_rh.tissuelabel     = atl_rh.aparclabel';
for t = 1:length(atl_rh.tissuelabel),
    atl_rh.tissuelabel{t} = [atl_rh.tissuelabel{t} '_right'];
end
atl_rh.name ='jwg_rh';
atlases{end+1} = atl_rh;

% MERGE THE TWO, JUST LIKE OTHER MOTOR ATLAS
% check that the tissues do not overlap
% assert(all(atl_lh.tissue(atl_rh.tissue > 0) == 0));

% now merge, bit clunky but should work
atl_jwg_combined = rmfield(atl_lh, {'aparc', 'aparclabel', 'cfg'});
atl_jwg_combined.tissue = zeros(size(atl_jwg_combined.tissue)); % start with empty

% find the indices where both have some defined voxels
lh_mask = (atl_lh.tissue > 0);
rh_mask = (atl_rh.tissue > 0);
dontuse_mask = lh_mask & rh_mask;

rh_tissue = atl_rh.tissue + 3;
rh_tissue(atl_rh.tissue == 0) = 0;
atl_jwg_combined.tissue = atl_lh.tissue + rh_tissue;
atl_jwg_combined.tissue(dontuse_mask) = 0;
atl_jwg_combined.tissuelabel = [atl_lh.tissuelabel atl_rh.tissuelabel];
atl_jwg_combined.name = 'jwg';
atlases{end+1} = atl_jwg_combined;

% AND ADD A SYMMETRICAL VERSION
atlases{end+1} = group_leftright(atl_jwg_combined);
atlases{end}.name = 'jwg_symm';

% ==================================================================
% SAVE THIS FILE
% ==================================================================

save(sprintf('%s/atlas_rois_clusters.mat', subjectdata.mridir), 'atlases');
disp(atlases);
disp('atlases saved');

% ==================================================================
% PLOT ALL
% ==================================================================

if plot_me,
    
    % atlases = atlases_all;
    for a = 1:length(atlases),
        
        % pretend the atlas is functional data
        atl                       = atlases{a};
        atl.tissue(atl.tissue == 0) = NaN;
        atl.mask = ~isnan(atl.tissue);
        
        close all;
        cfg.method                = 'surface'; % looks nicest
        cfg.projmethod            = 'project';
        cfg.surfinflated          = 'surface_inflated_both.mat'; % Inflated cortical surface
        cfg.camlight              = 'no';
        cfg.renderer              = 'opengl';
        %  cfg.funcolormap           = cbrewer('qual', 'Set2', numel(atl.tissuelabel));
        cfg.funcolormap           = 'viridis';
        cfg.funparameter          = 'tissue';
        cfg.maskparameter         = 'mask';
        %cfg.opacitylim            = [0 1];
        cfg.colorbar              = 'no';
        
        % NOTE: EDIT CORTEX_DARK AND CORTEX_LIGHT TO CHANGE TO GREY!
        ft_sourceplot(cfg, atl);
        
        if contains(atl.name, 'wang')
            view([-17 -7]);
        end
        
        title(sprintf('Atlas %d: %s', a, atlases{a}.name), ...
            'fontsize', 12, 'interpreter', 'none', 'fontweight', 'normal');
        
        % saveas(gcf, sprintf('%s/ROIs/%s_%s.fig', subjectdata.figsdir, ...
        %     atlases{a}.name, atl.tissuelabel{t}), 'fig');
        print(gcf, '-dpng', sprintf('%s/ROIs/atlas%d_%s.png', subjectdata.figsdir, ...
            a, atlases{a}.name));
        
    end
    
    % atlases = atlases_all;
    %     for a = length(atlases):-1:1,
    %         for t = 1:length(atlases{a}.tissuelabel),
    %
    %             % pretend the atlas is functional data
    %             atl                       = atlases{a};
    %             atl.mask                  = (atl.tissue == t);
    %             try
    %                 assert(mean(atl.mask(:)) > 0, 'no voxels remaining');
    %
    %                 close all;
    %                 cfg.method                = 'surface'; % looks nicest
    %                 cfg.projmethod            = 'project';
    %                 cfg.surfinflated          = 'surface_inflated_both.mat'; % Inflated cortical surface
    %                 cfg.camlight              = 'no';
    %                 cfg.renderer              = 'opengl';
    %                 cfg.funcolormap           = flipud(coolwarm);
    %                 cfg.maskparameter         = 'mask';
    %                 cfg.funparameter          = 'mask';
    %                 cfg.opacitylim            = [0 1];
    %                 cfg.colorbar              = 'no';
    %
    %                 % NOTE: EDIT CORTEX_DARK AND CORTEX_LIGHT TO CHANGE TO GREY!
    %                 ft_sourceplot(cfg, atl, template_sourcemodel.sourcemodel);
    %             end
    %
    %             view([-12 -4]);
    %             title(sprintf('Atlas %s, area %s', atlases{a}.name, atl.tissuelabel{t}), ...
    %                 'fontsize', 12, 'interpreter', 'none', 'fontweight', 'normal');
    %
    %             % saveas(gcf, sprintf('%s/ROIs/%s_%s.fig', subjectdata.figsdir, ...
    %             %     atlases{a}.name, atl.tissuelabel{t}), 'fig');
    %             print(gcf, '-dpng', sprintf('%s/ROIs/%s_%s.png', subjectdata.figsdir, ...
    %                 atlases{a}.name, regexprep(atl.tissuelabel{t}, '/', '')));
    %
    %         end
    %     end
end

end

% ============================================= %
% HELPER FUNCTIONS FOR CLUSTER DEFINITION
% ============================================= %

function atl2 = cluster_rois(atl1, roi_clusters)

% check that we're not missing areas!
% assert(numel(unique(atl1.tissue(~isnan(atl1.tissue)))) == length(atl1.tissuelabel));

% also define visual field maps based on combined regions
atl2                 = atl1;
atl2.tissuelabel     = {};
atl2.tissue          = zeros(size(atl2.tissue));

for r = 1:length(roi_clusters),
    
    % define the name for this clustered region
    atl2.tissuelabel{r}      = roi_clusters(r).name;
    tissues                  = find(ismember(atl1.tissuelabel, roi_clusters(r).regions));
    idx                      = ismember(atl1.tissue, tissues);
    
    area_diff = setdiff(roi_clusters(r).regions, atl1.tissuelabel(tissues));
    if numel(area_diff) > 0,
        warning('%s missing', area_diff{:});
    end
    
    if sum(idx(:)) == 0,
        warning('did not find any grid points for atlas %s, region %s', atl1.name, atl2.tissuelabel{r})
    else
        assert(all(atl2.tissue(idx)) == 0, 'this gridpoint already belongs to another cluster');
    end
    atl2.tissue(idx)         = r;
end
end

function clusters = get_clusters_wang1


clusters(1).name            = 'medialoccipital';
clusters(1).regions         = {'V1d', 'V2d', 'V3d', 'V1v', 'V2v', 'V3v'};

clusters(end+1).name        = 'lateraloccipital';
clusters(end).regions       = {'LO1', 'LO2', 'hMT'};

clusters(end+1).name        = 'ventraloccipital';
clusters(end).regions       = {'hv4', 'VO1', 'VO2', 'PHC1', 'PHC2'};

clusters(end+1).name        = 'dorsaloccipital';
clusters(end).regions       = {'V3a', 'V3b', 'IPS0'};

clusters(end+1).name        = 'posteriorparietal';
clusters(end).regions       = {'IPS0', 'IPS1','IPS2','IPS3','IPS4','IPS5'};

end

function clusters = get_clusters_wang2(lateralized)

% https://github.com/DonnerLab/pymeg/blob/master/pymeg/atlas_glasser.py#L226

clusters(1).name            = 'V1';
clusters(1).regions         = {'V1d', 'V1v'};

clusters(end+1).name        = 'V2-V4';
clusters(end).regions       = {'V2d', 'V2v', 'V3d', 'V3v', 'hV4'};

clusters(end+1).name        = 'VO1/2';
clusters(end).regions       = {'VO1', 'VO2'};

clusters(end+1).name        = 'PHC';
clusters(end).regions       = {'PHC1', 'PHC2'};

clusters(end+1).name        = 'V3A/B';
clusters(end).regions       = {'V3a', 'V3b'};

clusters(end+1).name        = 'MT/MST';
clusters(end).regions       = {'MST', 'hMT'};

% this one doesn't seem ported into the Fieldtrip version of the vtpm atlas
% clusters(end+1).name        = 'vfc_TO';
% clusters(end).regions       = {'TO1', 'TO2'};

clusters(end+1).name        = 'LO1/2';
clusters(end).regions       = {'LO1', 'LO2'};

clusters(end+1).name        = 'IPS0/1';
clusters(end).regions       = {'IPS0', 'IPS1'};

clusters(end+1).name        = 'IPS2/3';
clusters(end).regions       = {'IPS2', 'IPS3'};

clusters(end+1).name        = 'IPS4/5';
clusters(end).regions       = {'IPS4', 'IPS5'};

% clusters(end+1).name        = 'IPS2-5';
% clusters(end).regions       = {'IPS2', 'IPS3', 'IPS4', 'IPS5'};

clusters(end+1).name        = 'SPL1';
clusters(end).regions       = {'SPL1'};

clusters(end+1).name        = 'FEF';
clusters(end).regions       = {'FEF'};

% NOW RENAME TO MATCH THE GLASSER REGION NAMES
num_clusters = length(clusters);
for c = 1:length(clusters),
    num_regions = length(clusters(c).regions);
    for r = 1:length(clusters(c).regions),
        if ~lateralized,
            clusters(c).regions{r+num_regions}  = ['right_' clusters(c).regions{r}];
            clusters(c).regions{r}              = ['left_' clusters(c).regions{r}];
        elseif lateralized,
            % add the right one
            clusters(c + num_clusters).regions{r} = ['right_' clusters(c).regions{r}];
            if r == length(clusters(c).regions),
                clusters(c + num_clusters).name       = ['right_' clusters(c).name];
            end
            % rename the left one
            clusters(c).regions{r} = ['left_' clusters(c).regions{r}];
            if r == length(clusters(c).regions),
                clusters(c).name       = ['left_' clusters(c).name];
            end
            
        end
    end
end

end

function clusters = get_clusters_glasser(lateralized)

% LIST ALL CLUSTERS https://github.com/DonnerLab/pymeg/blob/master/pymeg/atlas_glasser.py#L287
% See also https://static-content.springer.com/esm/art%3A10.1038%2Fnature18933/MediaObjects/41586_2016_BFnature18933_MOESM330_ESM.pdf

clusters(1).name            = 'visual_primary';
clusters(1).regions         = {'V1'};

clusters(end+1).name        = 'visual_dors';
clusters(end).regions       = {'V2', 'V3', 'V4'};

clusters(end+1).name        = 'visual_ventral';
clusters(end).regions       = {'V3A', 'V3B', 'V6', 'V6A', 'V7', 'IPS1'};

clusters(end+1).name        = 'visual_lateral';
clusters(end).regions       = {'V3CD', 'LO1', 'LO2', 'LO3', 'V4t', 'FST', 'MT', 'MST', 'PH'};

clusters(end+1).name        = 'somato_sens_motor';
clusters(end).regions       = {'4', '3a', '3b', '1', '2'};

clusters(end+1).name        = 'paracentral_midcingulate';
clusters(end).regions       = {'24dd', '24dv', '6mp', '6ma', '5m', '5L', '5mv', '33pr', 'p24pr'};

% email Tobi, december 2021
% o	Dorsal: 6a, 6d
% o	Intermediate / ?eye fields": FEF, PEF, 55b (again: here ?FEF? refers to Glasser-FEF, not Wang-FEF!)
% o	Ventral: 6v, 6r

clusters(end+1).name        = 'PMd/v';
clusters(end).regions       = {'55b', '6d', '6a', 'FEF', '6v', '6r', 'PEF'};

clusters(end+1).name        = 'pos_opercular';
clusters(end).regions       = {'43', 'FOP1', 'OP4', 'OP1', 'OP2-3', 'PFcm'};

clusters(end+1).name        = 'audiotory_early';
clusters(end).regions       = {'A1', 'LBelt', 'MBelt', 'PBelt', 'RI'};

clusters(end+1).name        = 'audiotory_association';
clusters(end).regions       = {'A4', 'A5', 'STSdp', 'STSda', 'STSvp', 'STSva', 'STGa', 'TA2'};

clusters(end+1).name        = 'insular_front_opercular';
clusters(end).regions       = {'52', 'PI', 'Ig', 'PoI1', 'PoI2', 'FOP2', 'FOP3', 'MI', 'AVI', 'AAIC', 'Pir', 'FOP4', 'FOP5'};

clusters(end+1).name        = 'temporal_med';
clusters(end).regions       = {'H', 'PreS', 'EC', 'PeEc', 'PHA1', 'PHA2', 'PHA3'};

clusters(end+1).name        = 'temporal_lat';
clusters(end).regions       = {'PHT', 'TE1p', 'TE1m', 'TE1a', 'TE2p', 'TE2a', 'TGv', 'TGd', 'TF'};

clusters(end+1).name        = 'temp_par_occ_junction';
clusters(end).regions       = {'TPOJ1', 'TPOJ2', 'TPOJ3', 'STV', 'PSL'};

clusters(end+1).name        = 'parietal_sup';
clusters(end).regions       = {'LIPv', 'LIPd', 'VIP', 'AIP', 'MIP', '7PC', '7AL', '7Am', '7PL', '7Pm'};

clusters(end+1).name        = 'parietal_inf';
clusters(end).regions       = {'PGp', 'PGs', 'PGi', 'PFm', 'PF', 'PFt', 'PFop', 'IP0', 'IP1', 'IP2'};

clusters(end+1).name        = 'cingulate_pos';
clusters(end).regions       = {'DVT', 'ProS', 'POS1', 'POS2', 'RSC', 'v23ab', 'd23ab', '31pv', '31pd', '31a', '23d', '23c', 'PCV', '7m'};

clusters(end+1).name        = 'frontal_orbital_polar';
clusters(end).regions       = {'47s', '47m', 'a47r', '11l', '13l', 'a10p', 'p10p', '10pp', '10d', 'OFC', 'pOFC'};

clusters(end+1).name        = 'frontal_inferior';
clusters(end).regions       = { '44', '45', 'IFJp', 'IFJa', 'IFSp', 'IFSa', '47l', 'p47r'};

clusters(end+1).name        = 'dlpfc';
clusters(end).regions       = {'8C', '8Av', 'i6-8', 's6-8', 'SFL', '8BL', '9p', '9a', '8Ad', 'p9-46v', 'a9-46v', '46', '9-46d'};

clusters(end+1).name        = 'post_medial_frontal';
clusters(end).regions       = {'SCEF', 'p32pr', 'a24pr', 'a32pr', 'p24'};

clusters(end+1).name        = 'vent_medial_frontal';
clusters(end).regions       = {'p32', 's32', 'a24', '10v', '10r', '25'};

clusters(end+1).name        = 'ant_medial_frontal';
clusters(end).regions       = {'d32', '8BM', '9m'};

% NOW RENAME TO MATCH THE GLASSER REGION NAMES
num_clusters = length(clusters);
for c = 1:length(clusters),
    num_regions = length(clusters(c).regions);
    for r = 1:length(clusters(c).regions),
        if ~lateralized,
            clusters(c).regions{r+num_regions}  = ['R_' clusters(c).regions{r} '_ROI'];
            clusters(c).regions{r}              = ['L_' clusters(c).regions{r} '_ROI'];
        elseif lateralized,
            % add the right one
            clusters(c + num_clusters).regions{r} = ['R_' clusters(c).regions{r} '_ROI'];
            if r == length(clusters(c).regions),
                clusters(c + num_clusters).name       = ['right_' clusters(c).name];
            end
            % rename the left one
            clusters(c).regions{r} = ['L_' clusters(c).regions{r} '_ROI'];
            if r == length(clusters(c).regions),
                clusters(c).name       = ['left_' clusters(c).name];
            end
            
        end
    end
end

end

function clusters = get_clusters_motorcoords

% get motor regions defined from MNI coordinates, see
% https://github.com/anne-urai/MEG/blob/3e8743f2e8f24329e0b078a24747c0f73dd4fe9d/cleanUp_July2019/mri_selectROI_atlas.m#L322

clusters.roi_labels = {'M1_left', ...
    'PreCeS_left', ...
    'aIPS_left', ...
    'M1_right', ...
    'PreCeS_right', ...
    'aIPS_right'};
clusters.mnicoords  = {[-3.5 -2.6 5.8], ...
    [-3.1 -0.7 4.9],  ...
    [-3.9, -4.0, 5.6], ...
    [3.4 -2.7 5.8], ...
    [2.9 -0.7 5.3], ...
    [4.1 -4.2 5.6]}; % have been manually defined on template MRI

end

function clusters = group_leftright(lateralized)
% add one tissue idx that covers both left and right

clusters        = lateralized;
clusters.tissue = zeros(size(clusters.tissue));
clusters.tissuelabel = {};

% go through each tissue
left_rois = find(contains(lateralized.tissuelabel,'left', 'IgnoreCase',true));
assert(length(left_rois) > 0);
for l = 1:length(left_rois),
    
    left_tissue_idx = left_rois(l);
    right_tissue_idx = find(contains(lateralized.tissuelabel, ...
        regexprep(lateralized.tissuelabel(left_rois(l)), 'left', 'right'), 'ignorecase', true));
    
    % now build this into the new clusters atlas
    tissuename = regexprep(regexprep(lateralized.tissuelabel(left_rois(l)), 'left', ''), '_', '');
    clusters.tissuelabel(l) = tissuename;
    clusters.tissue(lateralized.tissue == left_tissue_idx) = l;
    clusters.tissue(lateralized.tissue == right_tissue_idx) = l;
    
end

end

