#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Mar 21 15:50:18 2022

@author: urai

Saves a leaner version of the CSV file for HDDMnn to reduce load on I/O of the home system on ALICE.
"""

import os
import pandas as pd

usr = os.environ['USER']
if 'aeurai' in usr:  # lisa
    datapath = '/home/aeurai/Data/MEG_HDDM'
elif 'urai' in usr:  # mbp laptop
    datapath = '/Users/urai/Data/projects/0/neurodec/Data/MEG-PL/'
    

# add repetition probability to split groups
data = pd.read_csv(os.path.join(datapath, 'CSV', 'allsubjects_megall_4hddm_norm_flip.csv'))

data = data[[
  'subj_idx',
  'session',
  'block',
  'trial',
  'stimulus',
  'hand',
  'response',
  'rt',
  'correct',
  'prevresp',
  'prevstim',
  'prev_correct',
  'repeat',
  'repetition',
  'group',
  'prevresp_correct',
  'prevresp_error',
  'alpha_ips01_stimwin_resid',
  'beta_3motor_lat_prestimwin',
  'beta_3motor_lat_refwin',
  'beta_3motor_lat_stimwin',
  'gamma_ips23_prestimwin',
  'gamma_ips23_refwin',
  'gamma_ips23_stimwin']]
data.to_csv(os.path.join(datapath, 'CSV', 'data_meg_hddmnn.csv'))
