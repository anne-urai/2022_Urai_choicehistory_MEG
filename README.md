Urai &amp; Donner (2022). Persistent Activity in Human Parietal Cortex Mediates Perceptual Choice Repetition Bias. _bioRxiv_, https://doi.org/10.1101/2021.10.09.463755

This script shows the order of running MEG analyses to reproduce the analyses and generate figures. 
If you use this code, please cite the paper.

Anne Urai, Leiden University, 2022
a.e.urai@fsw.leidenuniv.nl

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.6949711.svg)](https://doi.org/10.5281/zenodo.6949711)

# Data #

Processed (ROI-extracted) data can be found at https://osf.io/v3r52/. Their format is explained [here](https://github.com/anne-urai/2022_Urai_choicehistory_MEG/tree/main/Data_description.md).

Unfortunately, the raw data cannot be shared due to our consent form used at the time of data collection, and privacy regulations at our institutes. Please contact Anne Urai for access.

# Requirements #
- Matlab
- FieldTrip http://www.fieldtriptoolbox.org/
- some miscellaneous functions from https://github.com/anne-urai/Tools
- Rstudio with lavaan https://lavaan.ugent.be/
- Python with the HDDMnn (LAN extension) toolbox http://ski.clps.brown.edu/hddm_docs/

# Code #

## Task ##

See [Task_PTB_2IFC_MEG](https://github.com/anne-urai/2022_Urai_choicehistory_MEG/tree/main/Task_PTB_2IFC_MEG).

## MEG preprocessing ##
``` matlab
subjectdata = subjectspecifics('GA');
for sj = subjectdata.all, preproc_readMEG(sj); end % read in all MEG files
for sj = subjectdata.all, preproc_cleanUp(sj); end % reject trials + write clean csv file
for sj = subjectdata.all, preproc_appendRecs(sj); end % append within each session
```

### Create behavioral summary file ###
``` matlab
preproc_writeCSV; % writes allsubjects_meg.csv, with only behavioral info
```

### Epoch trials ###
```matlab
for sj = subjectdata.clean, preproc_redefineFiles(sj); end % into ref, stim, resp and fb
```

### Preprocess for TFR sensor-level plots ###

``` matlab
for sj = subjectdata.clean, tfr_computePow(sj); end % computes power for each single trial
for sj = subjectdata.clean, tfr_computeEvokedPow(sj); end % also evoked-only power for computing the phase-locked gamma
for sj = subjectdata.clean, tfr_contrasts(sj); end % power for specific subsets of trials
for n = 1:25, tfr_grandAverage(n, 1:2, 1, 1, 1); end % do grand average across ERFs and TFRs
```

### Plot TFRs at the sensor level ###

``` matlab
for n = 2:7,sensorplot_clusterStatsTFR_defineSens(n); end
sensorplot_sensordefinition;
for n = 2:7, sensorplot_clusterStatsTFR_forTFR(n); end
sensorplot_plotTFR('GAclean');
```

### Evoked vs. Induced activity ###
``` matlab
tfr_induced_evoked; % plot the evoked vs. total (evoked + induced) power for determining the visual gamma frequency band
```

## Source reconstruction with DICS ##

### Preprocess MRIs ###
``` matlab
mri_templateMRI; % choose template
for sj = subjectdata.clean, mri_makeHeadmodel(sj); end % for each subject, make a headmodel
for sj = subjectdata.clean, mri_makeLeadfields; end % make the leadfields from the headmodel and sensor position
```


### Run DICS beamformer ###
```matlab
for sj = subjectdata.clean, dics_beamformer; end % beamforms for each epoch and freq range
```

### Parcellate into ROIs ###
``` matlab
dics_atlases; % this will also output the inflated cortex with the maps on top
for sj = subjecdata.clean, dics_parcellate; end
dics_grandaverage; # create one large file to work with + lateralize
```

After this, parcellated files can be copied and the rest of the analyses can be run locally.

### Plot ROIs on inflated surface ###
Requires PySurfer: https://gist.github.com/danjgale/4f64ca81f5e91cc0669d0f744c7a9f82, see `pysurfer_env.yml`.

``` python
python plot_inflated_surface.py # runs on MBP: conda activate pysurfer
```

### Plot ROI timecourses ###
``` matlab
dics_plot_timecourses(0, 2:3, 1); % timecourses in figure 2 and 3
```

### GLME to compute history effects ###

```matlab
dics_effects; % not used to plot, but saves csv with all effect sizes

% =================== %
% APPEND
% =================== %

sjdat = subjectspecifics('ga');
freqs = dics_freqbands; % retrieve specifications

for v = 1:3,
    files = dir(sprintf('%s/GrandAverage/Stats/dics_effects/effects_*%s_*.csv', ...
        sjdat.path, freqs(v).name));
    % disp(files);
    for f = 1:length(files),
        table_files{f} = readtable(sprintf('%s/%s', files(f).folder, files(f).name));
    end
    tab_all = cat(1, table_files{:});
    writetable(tab_all, sprintf('%s/effectsizes_%s.csv', sjdat.statsdir, freqs(v).name));
    fprintf('%s/effectsizes_%s.csv \n ', sjdat.statsdir, freqs(v).name)
end

dics_singletrial_writecsv; % writes allsubjects_meg_complete.csv (all trials, all ROIs) and allsubjects_meg_lean.csv (smaller, for HDDMnn and mediaiton)
```

### Plot GLME history effects ###
```matlab
dics_scalars_stats; % all panels across areas in figures 2 and 3
dics_stats_print_summary;
dics_stats_groupdiff; % figure 4, between-subject correlations and group effects
dics_scalars_stats_multitrial;
dics_plot_effect_timecourses;
```

## Behavior ##

History kernels from Fruend code. This only runs locally in `python2.7`, unfortunately.
``` python
behavior_plots.py # figure 1
behavior_kernels_fit.py # for supplementary figure
behavior_multitrial.py
```

### Mediation analyses in R, plotting in Python ###
``` R
mediation_lavaan.R # main mediation analysis
mediation_lavaan_wm.R # working memory control analysis with baseline signal
```
``` python
mediation_lavaan_plot.py
```

## HDDMnn fits ##
You'll need to run this from a conda environment with HDDM installed: http://ski.clps.brown.edu/hddm_docs/#installation. These fits were run in the `hddm_env2.yml` conda env on the [ALICE cluster](https://wiki.alice.universiteitleiden.nl/index.php?title=ALICE_User_Documentation_Wiki).

``` python
hddmnn_fit.py # fits all regression models, with and without neural data. see also stopos/hddm_submit
hddmnn_plot.py # plots main summary of regression models without neural data (replicate eLife paper)
```
