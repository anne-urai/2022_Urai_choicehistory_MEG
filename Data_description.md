Description and explanation of MEG (ROI-extracted) data, to be found at https://osf.io/v3r52/. 
Unfortunately, the raw data cannot be shared due to our consent form used at the time of data collection, and privacy regulations at our institutes. Please contact Anne Urai for access.

Anne Urai, Leiden University, 20 September 2021
a.e.urai@fsw.leidenuniv.nl

---

### MEG ROI data
Each main file has the following title:
- `GA` ('grand average', all data from the 60 participants together)
- `-S1` or `-S2`, for session 1 or session 2 in the MEG (with practice in between)
- `_parcel_`, these are beamformed and parcellated into atlases, see Methods section
- `_alpha_`, `_beta_`, `_gamma_` for the frequency band, see Methods section

Each file contains a [FieldTrip](https://www.fieldtriptoolbox.org/faq/how_are_the_various_data_structures_defined/)-like data structure:

```matlab
source = 

  struct with fields:

         freq: 80
         time: [1×163 double]
        label: {62×1 cell}
          pow: [62×23932×163 double]
    powdimord: 'chan_rpt_time'
    trialinfo: [23932×18 double]
```

- `freq`: the center frequency of each band. More information that was used to determine the frequency bands
	- _alpha_: freq = 10, timewin = 0.5, tapsmofrq = 3 (so 7 - 13 Hz)
	- _beta_: freq = 24, timewin = 0.5, tapsmofrq = 12 (so 12 - 36 Hz)
	- _gamma_: freq = 80, timewin = 0.4, tapsmofrq = 15 (so 65 - 95 Hz)
- `time`: time axis during the trial. 
	- This is chopped up into 4 epochs: refererence, test stimulus, response, feedback. Each epoch's onset is at 0, and the breaks between epochs (due to jitter between them) is indicated with some padded NaNs. This allows you to plot the whole timecourse as in e.g. Figure 1e: take `1:length(source.time)` as the x-axis, and then use the function `timename.m` to recode this and indicate the 0-points for all 4 events.
- `label`: the label of each ROI that was selected for analysis. 
	- `glasser`/`wang`/`jwg` indicates the atlas of provenance (see Methods table)
		- for `wang`, `vfc` indicates that the individual regions from the original paper have been grouped into visual field clusters, see Methods for grouping
	- those with `left`, `right` are from one side of the brain
		- those with `lateralized` are left-right, useful for the motor signals
		- those without these terms, or `symm`, are symmetrical: the average signal from left and right ROIs
- `powdimord` is a FieldTrip indication of the dimensions of `pow`: first channels (= labels, aka ROIs), then repetitions (= trials), then timepoints within the trial
- `pow` has the beamformed power modulation values
- `trialinfo` is a table with columns that describe each trial. Since Matlab can't have a table within a structure, I'm attaching a separate `allsubjects_meg.csv` table which has column names that are easier to work with. They two can be mapped to ensure that you're working with the correct trials, see the code snipperts below.
	- the column names in the `csv` file hopefully speak for themselves: for `hand` and `start_hand` (you can ignore the latter), the mapping is 12 -> left and 18 -> right. `idx` is a simple mapping variable that also exists in `source.trialinfo`.

Run the following Matlab code to work with the data
```matlab       
sjdat = subjectspecifics('ga');

% ============================ %
% load behavioral data
% ============================ %

tab = readtable(sprintf('%s/allsubjects_meg.csv', sjdat.csvdir));
tab = tab(ismember(tab.subj_idx, sjdat.clean), :); % remove 1 bad subject

% ============================ %
% load the MEG data
% ============================ %

source = load(sprintf('%s/GA-S%d_parcel_%s.mat', sjdat.roidir, ...
         session, freqs(v).name));
source = source.source;

% remove some ugly stuff in the beginning and between epochs
if session ~= 5,
	rmidx = [1:4, 31:41, 45:48, 79:85, 123:length(source.time)];
	source.pow(:, :, rmidx) = [];
	source.time(rmidx) = [];
end

% REMOVE NANS FROM TIMECOURSE - make the epoch borders smaller
% for better plotting
startSeq = strfind(squeeze(isnan(nanmean(nanmean(source.pow))))', true(1,3));
removeidx = false(1, length(source.time));
for s = 1:length(startSeq),
	removeidx(startSeq(s)+1 : startSeq(s)+1) = 1;
end
source.pow(:, :, removeidx) = [];
source.time(removeidx) = [];

% ============================ %
% map them together 
so you can work with the table
% ============================ %

[~, ~, tidx]    = intersect(source.trialinfo(:, 18), tab.idx, 'stable');
assert(size(source.trialinfo, 1) == length(tidx));
tab             = tab(tidx, :); % keep only that part of the table
assert(isequal(tab.idx, source.trialinfo(:, 18)), 'idx do not match');
```

### Behavioral and summary data
Apart from the `.mat` and `allsubjects_meg.csv` files, I'm also including 
- `allsubjects_meg_complete.csv`. This has beamformed power modulation values per time window of interest, so it's much smaller but easier to work with. The lateralization MEG values have been flipped for half the subjects, to account for the stimulus-response mapping counterbalancing. It has all trials, time windows and ROIs (with `nan` for trials where the MEG was rejected).
- `allsubjects_meg_lean.csv`, a much smaller file with only those trials with MEG, and those MEG trial-by-trial signals that are used for HDDM modelling and mediation. 

Email me if you have any questions.