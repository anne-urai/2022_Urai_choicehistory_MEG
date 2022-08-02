#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Jan  3 13:32:24 2022

@author: urai
This needs to be run locally in the python2 env

"""

import pandas as pd
import scipy as sp
import pylab as pl
import numpy as np

# need https://bitbucket.org/mackelab/serial_decision/src/master/intertrial/
# the code used here lives at https://github.com/anne-urai/2017_Urai_pupil-uncertainty/tree/master/serial-dependencies
import sys, os, cPickle
sys.path.append('/Users/urai/Documents/code/2017_NatCommun_Urai_pupil-uncertainty/serial-dependencies/')
from intertrial import util
import pdb

#%% write Frund-compatible txt files
datapath = '/Users/urai/Data/projects/0/neurodec/Data/MEG-PL/'
# take the full behavioral data, without removing bad MEG trials!
data = pd.read_csv(os.path.join(datapath, 'CSV', 'allsubjects_meg.csv'))

# Note that the data file should have a canonical structure with 5 columns
# block    condition    stimulus    target    response
# where each row contains the respective information for a single trial.
data.block = data.block + data.session * 10
data['stimstrength'] = 1
data.stimulus = 1*(data.stimulus > 0)
data.response = 1*(data.response > 0)

# write small txt files
for sj, dat in data[['block', 'session', 'stimstrength', 
                     'stimulus', 'response', 'subj_idx']].groupby(['subj_idx']):
    
    filename = os.path.join(datapath, 'CSV', 'Fruend', 'sj_%02d.txt'%sj)
    backup_file = os.path.join(datapath, 'CSV', 'Fruend', 'sj_%02d_kernels.csv'%sj)
    
    # write file 
    if not os.path.exists(filename):
        print(filename)
        dat.drop(columns=['subj_idx']).to_csv(filename, index=False, header=False, sep=' ') # write temporary file
    
    # run analysis
    if not os.path.exists(backup_file):
        print(backup_file)
        data, w0, plotinfo = util.load_data_file(filename) # load back in, find starting point
        results = util.analysis(data, w0, nsamples=5000) # now analyze, dont bootstrap
        
        # # plot the results
        # util.plot ( data, results, plotinfo )
        # pl.savefig ( os.path.join (datapath, 'CSV', 'Fruend', 'sj_%02d.pdf'%sj))
        
        # get what we need from this history object
        Mh = results['model_w_hist']
        resp_kernel = Mh.w[Mh.hf0:Mh.hf0+data.hlen]
        stim_kernel = Mh.w[Mh.hf0+data.hlen:]
        
        # crucial: project back into lag space
        resp_kernel = np.dot(resp_kernel, data.h.T)
        stim_kernel = np.dot(stim_kernel, data.h.T)
        
        df = pd.DataFrame({'stim_kernel':stim_kernel, 'resp_kernel':resp_kernel})
        df.to_csv(backup_file)
        
        # write the loglikelihoods of the 2 models
        ll_h = results['model_w_hist'].loglikelihood
        ll_nh = results['model_nohist'].loglikelihood
        pd.DataFrame({'hist':ll_h, 'nohist':ll_nh}, index=[0]).to_csv(os.path.join(datapath, 
                                                                             'CSV', 'Fruend', 'sj_%02d_loglikelihoods.csv'%sj))
        # write the permuted distributions
        pd.DataFrame(results['permutation_wh']).to_csv(os.path.join(datapath, 'CSV', 'Fruend', 'sj_%02d_perm_wh.csv'%sj))
        pd.DataFrame(results['permutation_nh']).to_csv(os.path.join(datapath, 'CSV', 'Fruend', 'sj_%02d_perm_nh.csv'%sj))

