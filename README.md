# 2021_Urai_choicehistory_MEG
Urai &amp; Donner (2021). Parietal and Motor Cortical Dynamics Differentially Shape the Computation of Choice History Bias. _bioRxiv_

This script shows the order of running MEG analyses to reproduce the analyses and generate figures. If you use it, please cite the paper.
<!-- -->

### Requirements ##
- Matlab
- FieldTrip http://www.fieldtriptoolbox.org/
- some miscellaneous functions from https://github.com/anne-urai/Tools
- Rstudio with lavaan https://lavaan.ugent.be/
- Python with the HDDM toolbox http://ski.clps.brown.edu/hddm_docs/

## Analysis
### Preprocessing ##

``` matlab
motionEnergy_filtering;
motionEnergy_collect;
```

#### MEG ####
``` matlab
subjectdata = subjectspecifics('GA');

for sj = subjectdata.all, preproc_readMEG(sj); end % read in all MEG files
for sj = subjectdata.all, preproc_cleanUp(sj); end % reject trials + write clean csv file
for sj = subjectdata.all, preproc_appendRecs(sj); end % append within each session

```

#### Behavior ####
``` matlab
preproc_writeCSV; % write csv data from MEG, only behavior info
behavior_plots;
% the exclusion of 1 bad subjects is incorporated into subjectspecifics.m
```

#### Epoch trials ####

```matlab
for sj = subjectdata.clean, preproc_redefineFiles(sj); end % into ref, stim, resp and fb
```

### TFR sensor-level##

``` matlab
for sj = subjectdata.clean, tfr_computePow(sj); end % computes power for each single trial

for sj = subjectdata.clean, tfr_computeEvokedPow(sj); end % also evoked-only power for computing the phase-locked gamma

for sj = subjectdata.clean, tfr_contrasts(sj); end % power for specific subsets of trials

for n = 1:25, tfr_grandAverage(n, 1:2, 1, 1, 1); end % do grand average across ERFs and TFRs
```

#### Plot all TFRs at the sensor-level ####

``` matlab
for n = 2:7,sensorplot_clusterStatsTFR_defineSens(n); end

sensorplot_sensordefinition;

for n = 2:7, sensorplot_clusterStatsTFR_forTFR(n); end

sensorplot_plotTFR('GAclean');

tfr_induced_evoked; % plot the evoked vs. total (evoked + induced) power for determining the visual gamma frequency band

```

### DICS source reconstruction ##

#### MRI ####
``` matlab
mri_templateMRI; % choose template

for sj = subjectdata.clean, mri_makeHeadmodel(sj); end % for each subject, make a headmodel

for sj = subjectdata.clean, mri_makeLeadfields; end % make the leadfields from the headmodel and sensor position
```

#### Beamformer ####
```matlab
for sj = subjectdata.clean, dics_beamformer; end % beamforms for each epoch and freq range

dics_atlases; % this will also output the inflated cortex with the maps on top

for sj = subjecdata.clean, dics_parcellate; end

dics_grandaverage; # create one large file to work with + lateralize
```

#### PLOT ALL ROIS ON NICE INFLATED SURFACE ####
Requires PySurfer: https://gist.github.com/danjgale/4f64ca81f5e91cc0669d0f744c7a9f82

``` python
python plot_inflated_surface.py # runs on MBP: conda activate pysurfer
```

### Compute history effects ##
``` matlab
dics_plot_timecourses; % timecourses in figure 2 and 3
dics_effects; % effect size timecourses + glme estimates

% =================== %
% APPEND
% =================== %

sjdat = subjectspecifics('ga');
freqs = dics_freqbands; % retrieve specifications

for v = 1:3,
    files = dir(sprintf('%s/GrandAverage/Stats/dics_effects/effects_*%s_*.csv', ...
        sjdat.path, freqs(v).name));
    disp(files);
    for f = 1:length(files),
        table_files{f} = readtable(sprintf('%s/%s', files(f).folder, files(f).name));
    end
    tab_all = cat(1, table_files{:});
    writetable(tab_all, sprintf('%s/effectsizes_%s.csv', sjdat.statsdir, freqs(v).name));
    fprintf('%s/effectsizes_%s.csv \n ', sjdat.statsdir, freqs(v).name)
end
```
GLME summary figures
``` matlab
dics_scalars_stats; % all panels across areas in figures 2 and 3
dics_stats_print_summary;

dics_singletrial_writecsv; % the last script will also write a csv file for HDDM and mediation
% this will include 'flipped' lateralization signals and alpha/gamma residuals

```

### MEDIATION ANALYSIS in R

``` R
mediation_lavaan.R
```
``` python
mediation_lavaan_plot.py
```


### FIT HDDM MODELS USING DATA WITH MEG TRIALS ##
You'll need to run this from a conda environment with HDDM installed: http://ski.clps.brown.edu/hddm_docs/#installation. All scripts run in the `pysurfer` conda env except for `hddm_fit.py`, which runs in `python27` on the LISA cluster.

``` python
hddm_fit_fromvar.py # fits all regression models, with and without neural data. see also stopos/hddm_submit

hddm_plot_basic.py # plots main summary of regression models without neural data (replicate eLife paper).
hddm_plotparams_allvar.py # plots posterior and individual point estimates for all models
```

### Individual differences ##
``` matlab
behavior_individualdiffs;
dics_stats_groupdiff; % figure 4, between-subject correlations and group effects
behavior_historymodel;
```

### Supplementary figures ##
``` matlab
behavior_plots; % suppfig1
behavior_pharma; behavior_pharma_plot; % suppfig2

for sj = subjectdata.clean, heartrate_preprocess(sj); end; % preprocess heartrate data
heartrate_summarize;
heartrate_plot;

```
