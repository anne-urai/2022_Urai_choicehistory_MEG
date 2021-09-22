"""
from Peter Murphy, adapted by Anne Urai
requires pysurfer installation https://gist.github.com/danjgale/4f64ca81f5e91cc0669d0f744c7a9f82
run from conda env 'pysurfer'
"""


import matplotlib
import os
import glob
import numpy as np
from surfer import Brain
from mne import Label
import time
import seaborn as sns

import os
os.environ['SUBJECTS_DIR'] = '/Users/urai/Data/projects/0/neurodec/Data/MEG-PL/GrandAverage/MRI/JW_mriLabels/'
fs_dir = os.environ['SUBJECTS_DIR']
savepath = '/Users/urai/Data/projects/0/neurodec/Data/MEG-PL/Figures/'

#%matplotlib qt
# ===========================================

subject_id = 'fsaverage'
hemi = 'lh'
surf = 'inflated'
annotation = 'HCPMMP1'

label_names = glob.glob(os.path.join(
    fs_dir, subject_id, 'label', 'lh*.label'))
# print(label_names)

ROIs = [	['wang2015atlas.V1d','wang2015atlas.V1v'],
			['wang2015atlas.V2d','wang2015atlas.V2v','wang2015atlas.V3d',
        		'wang2015atlas.V3v','wang2015atlas.hV4'],
			['wang2015atlas.TO1','wang2015atlas.TO2'], # hMT/MST
			['wang2015atlas.V3A','wang2015atlas.V3B'],
			['wang2015atlas.IPS0','wang2015atlas.IPS1'],
			['wang2015atlas.IPS2','wang2015atlas.IPS3'],
		# 	['wang2015atlas.IPS4','wang2015atlas.IPS5'],
			['JWG_lat_aIPS'], 
			['JWG_lat_IPS_PCeS'],
			['L_55b_ROI','L_6d_ROI','L_6a_ROI','L_FEF_ROI','L_6v_ROI','L_6r_ROI','L_PEF_ROI'],
			['JWG_lat_M1']]

# ===========================================

# create an inflated surface
brain = Brain(subject_id, hemi, surf, background='white', offscreen=True, size=1200)

# PLOT LABEL FILES: WANG AND JWG ATLASES
cmap = sns.color_palette('viridis', n_colors=len(ROIs) + 1)

for roi, color in zip(ROIs, cmap):
	for r in roi: # plot each ROI separately onto the surface
		label_file = [l for l in label_names if r in l]
		if len(label_file):
			print(label_file)
			brain.add_label(label_file[0], color=color, alpha=0.8)
		#time.sleep(0.2)

# PLOT ANNOTATIONS FROM GLASSER
from nibabel.freesurfer import io
ids, colors, annot_names = io.read_annot(os.path.join(
    fs_dir, subject_id, 'label', 'lh.%s.annot' % annotation),
    orig_ids=True)

for roi, color in zip(ROIs, cmap):
	for i, alabel in enumerate(annot_names):
		if any([label in alabel.decode('utf-8') for label in roi]):
			label_id = colors[i, -1]
			vertices = np.where(ids == label_id)[0]
			l = Label(np.sort(vertices), hemi='lh')
			brain.add_label(l, color=color, alpha=0.8)
			#time.sleep(0.2)

# ===========================================
# I think one needs two separate angles to really appreciate the layout. 
# You can make it half the size and show a lateral and posterior view.

for v in ['lateral', 'parietal', 'caudal']:
	print(v)
	brain.show_view(v)
	time.sleep(1) # give mayavi time to draw
	brain.save_image("%sinflated_brain_rois_%s.pdf" %(savepath, v), mode='rgb')


# from https://github.com/DonnerLab/2020_Large-scale-Dynamics-of-Perceptual-Decision-Information-across-Human-Cortex/blob/936a4877ed2af1fed1e0ca8bbe06c59f8b227cf9/conf_analysis/meg/figures.py#L925
brain.show_view(dict(azimuth=-40, elevation=100))
time.sleep(1) # give mayavi time to draw
brain.save_image("%sinflated_brain_rois_%s.pdf" %(savepath, 'view1'), mode='rgb')

brain.show_view(dict(azimuth=-145, elevation=70))
time.sleep(1) # give mayavi time to draw
brain.save_image("%sinflated_brain_rois_%s.pdf" %(savepath, 'view2'), mode='rgb')



"""
second script, one image per ROI
merge the 3 motor ROIs
"""

ROIs = [	['wang2015atlas.V1d','wang2015atlas.V1v'],
			['wang2015atlas.V2d','wang2015atlas.V2v','wang2015atlas.V3d',
        		'wang2015atlas.V3v','wang2015atlas.hV4'],
			['wang2015atlas.TO1','wang2015atlas.TO2'], # hMT/MST
			['wang2015atlas.V3A','wang2015atlas.V3B'],
			['wang2015atlas.IPS0','wang2015atlas.IPS1'],
			['wang2015atlas.IPS2','wang2015atlas.IPS3'],
		# 	['wang2015atlas.IPS4','wang2015atlas.IPS5'],
			['JWG_lat_aIPS'],
			['JWG_lat_IPS_PCeS', 'L_55b_ROI','L_6d_ROI',
			 'L_6a_ROI','L_FEF_ROI','L_6v_ROI','L_6r_ROI','L_PEF_ROI','JWG_lat_M1']]

# PLOT LABEL FILES: WANG AND JWG ATLASES
cmap = sns.color_palette('viridis', n_colors=len(ROIs) + 1)

for ridx, (roi, color) in enumerate(zip(ROIs, cmap)):

	# create an inflated surface
	brain = Brain(subject_id, hemi, surf, background='white', offscreen=True, size=1200)

	for r in roi: # plot each ROI separately onto the surface
		label_file = [l for l in label_names if r in l]
		if len(label_file):
			print(label_file)
			brain.add_label(label_file[0], color=color, alpha=0.8)
		#time.sleep(0.2)

	# PLOT ANNOTATIONS FROM GLASSER
	from nibabel.freesurfer import io
	ids, colors, annot_names = io.read_annot(os.path.join(
		fs_dir, subject_id, 'label', 'lh.%s.annot' % annotation),
		orig_ids=True)

	for i, alabel in enumerate(annot_names):
		if any([label in alabel.decode('utf-8') for label in roi]):
			label_id = colors[i, -1]
			vertices = np.where(ids == label_id)[0]
			l = Label(np.sort(vertices), hemi='lh')
			brain.add_label(l, color=color, alpha=0.8)
			#time.sleep(0.2)

	# ===========================================
	# I think one needs two separate angles to really appreciate the layout.
	# You can make it half the size and show a lateral and posterior view.

	for v in ['lateral', 'parietal', 'caudal']:
		print(v)
		brain.show_view(v)
		time.sleep(1) # give mayavi time to draw
		brain.save_image("%sinflated_brain_rois_%s_%d.pdf" %(savepath, v, ridx), mode='rgb')

	# from https://github.com/DonnerLab/2020_Large-scale-Dynamics-of-Perceptual-Decision-Information-across-Human-Cortex/blob/936a4877ed2af1fed1e0ca8bbe06c59f8b227cf9/conf_analysis/meg/figures.py#L925
	brain.show_view(dict(azimuth=-40, elevation=100))
	time.sleep(1) # give mayavi time to draw
	brain.save_image("%sinflated_brain_rois_%s_%d.pdf" %(savepath, 'view1', ridx), mode='rgb')

	brain.show_view(dict(azimuth=-145, elevation=70))
	time.sleep(1) # give mayavi time to draw
	brain.save_image("%sinflated_brain_rois_%s_%d.pdf" %(savepath, 'view2', ridx), mode='rgb')
