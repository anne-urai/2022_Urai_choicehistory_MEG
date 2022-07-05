function [] = tools_compileMe(fname)

  % make my life easier
  if ~exist('fname', 'var'); fname = 'B1_redefineFiles.m';
  end
  if ~strcmp(fname(end-1:end), '.m'); fname = [fname '.m'];
  end % add extension
  disp(fname);

  % these paths will be added at compilation
  addpath(genpath('~/code/Tools'));
  addpath('~/Documents/fieldtrip');
  ft_defaults; % add everything to path that we need
  addpath(genpath('~/Documents/fieldtrip/template/')); % neighbouring matfile

  % for runica, need EEGlab
  switch fname
  case 'A5a_ICA_decompose.m',
    disp('adding fastica to path');
    addpath('~/Documents/fieldtrip/external/fastica/');
  case {'A4_makeHeadmodel.m', 'B6a_beamformer.m', 'A5b_makeLeadfields.m'},
    disp('adding spm and freesurfer to path');
    addpath('~/Documents/fieldtrip/external/spm8/templates');
    addpath('~/Documents/fieldtrip/external/spm8');
    addpath('~/Documents/fieldtrip/external/freesurfer/');
  case {'B3a_clusterStatsERF.m', 'B3b_clusterStatsTFR.m'},
    addpath('~/Documents/fieldtrip/statfun/'); % need the combineClusters mex file
    addpath('~/Documents/fieldtrip/external/spm8/'); % for neighbour definition
    % http://mailman.science.ru.nl/pipermail/fieldtrip/2014-July/008238.html
  case {'A2_motionFiltering.m', 'A2a_motionCollect.m', 'A2b_motionNormalise.m'}
    addpath('~/code/motionEnergy');
  end

  % options: compile verbose, only use the toolboxes we really need
  % !!! runtime options should be preceded by - to work!
  % dont need to activate the -nojvm flag, can still plot from executable
  switch fname
  case {'B3a_clusterStatsERF.m', 'B3b_clusterStatsTFR.m', ...
    'B6d_clusterStatsSource.m', 'B6c_sourceGrandaverage.m', 'B3b_clusterStatsTFR_fullCluster.m',...
	'F6_fullTFR_individualcorrelation.m', 'F6c_fullTFR_individualcorrelation_reg.m'},
    % statfun is called with a weird eval construction, so not recognized
    % by the dependency analysis of mcc
    mcc('-mv', '-N', '-p', 'stats', '-p', 'images', '-p', 'signal', ...
    '-R', '-nodisplay', '-R', '-singleCompThread', ...
    '-a', '~/Documents/fieldtrip/external/freesurfer/MRIread', ...
    '-a', '~/Documents/fieldtrip/external/dmlt/external/murphy/KPMtools/', ...
    '-a', '~/Documents/fieldtrip/ft_statistics_montecarlo.m', ...
    '-a', '~/Documents/fieldtrip/statfun/ft_statfun_depsamplesT.m', ...
    '-a', '~/Documents/fieldtrip/statfun/ft_statfun_indepsamplesregrT.m', ...
    '-a', '~/Documents/fieldtrip/statfun/ft_statfun_correlationT.m', ...
    '-a', '~/Documents/fieldtrip/external/spm12/spm_bwlabel.m', ...
    fname);

  case 'dics_beamformer.m',
    % for the fname function
    % addpath('~/Documents/fieldtrip/external/spm8/@meeg');
    disp('including fname');
    mcc('-mv', '-N', '-p', 'stats', '-p', 'images', '-p', 'signal', ...
    '-R', '-nodisplay', '-R', '-singleCompThread', ...
    '-a', '~/Documents/fieldtrip/external/spm8/spm.m', ...
    '-a', '~/Documents/fieldtrip/external/spm8/templates/T1.nii', ...
    '-a', '~/Documents/fieldtrip/external/freesurfer/MRIread', ...
    '-a', '~/code/Tools/spmbug/dim.m', ...
    '-a', '~/code/Tools/spmbug/dtype.m', ...
    '-a', '~/code/Tools/spmbug/fname.m', ...
    '-a', '~/code/Tools/spmbug/offset.m', ...
    '-a', '~/code/Tools/spmbug/scl_slope.m', ...
    '-a', '~/code/Tools/spmbug/scl_inter.m', ...
    '-a', '~/code/Tools/spmbug/permission.m', ...
    '-a', '~/code/Tools/spmbug/niftistruc.m', ...
    '-a', '~/code/Tools/spmbug/read_hdr.m', ...
    '-a', '~/code/Tools/spmbug/getdict.m', ...
    '-a', '~/code/Tools/spmbug/read_extras.m', ...
    '-a', '~/code/Tools/spmbug/read_hdr_raw.m', ...
    '-a', '~/Documents/fieldtrip/external/dmlt/external/murphy/KPMtools/', ...
    fname);

  otherwise

    % determine the path to the data
    usr = getenv('USER');
    switch usr
    case 'aurai' % uke cluster
      % ALLOW HYPERTHREADING
      mcc('-mv', '-N', '-p', 'stats', '-p', 'images', '-p', 'signal', ...
      '-R', '-nodisplay', fname);

    case 'aeurai' % cartesius/lisa

      % send this to the system as a command line, will not keep compiler license occupied
      % https://userinfo.surfsara.nl/systems/cartesius/software/matlab
      str = sprintf('echo "disp(pwd); tools_addToolsFieldtrip; mcc -mv -p stats -p images -p signal -R -nodisplay -R -singleCompThread %s" | matlab -nodisplay', fname);
      disp(str);
      disp('go')
      system(str);

    otherwise
      error('could not find the data path');
    end
  end

  % move to stopos folder
  movefile(fname(1:end-2), ['stopos/' fname(1:end-2)])

  % cleanup
  delete mccExcludedFiles.log
  delete run*.sh
  delete readme.txt
  delete requiredMCRProducts.txt
  disp(datestr(now));

end