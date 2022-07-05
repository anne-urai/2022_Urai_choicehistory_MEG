"""
fit HDDMnn models on ALICE
Anne Urai, Leiden University, 2022

"""

# ============================================ #
# GETTING STARTED
# ============================================ #

# warning settings
import warnings
warnings.simplefilter(action='ignore', category=FutureWarning)
import os, time, pprint, glob

import matplotlib as mpl
mpl.use('Agg')  # to still plot even when no display is defined
from optparse import OptionParser
import pandas as pd
import numpy as np
import seaborn as sns
sns.set()

# import HDDMnn functions, defined in a separate file
import hddmnn_funcs

# read inputs
parser = OptionParser("HDDM_run.py [options]")
parser.add_option("-m", "--model",
                  default=[0],
                  type="int",
                  help="number of the model to run")
parser.add_option("-i", "--trace_id",
                  default=0,
                  type="int",
                  help="number of the trace id to run")
parser.add_option("-d", "--dataset",
                  default=0,
                  type="int",
                  help="dataset nr")
opts, args = parser.parse_args()

# ============================================ #
# READ INPUT ARGUMENTS; DATAFILE
# ============================================ #

# find path depending on location and dataset
usr = os.environ['USER']
if 'aeurai' in usr: # lisa
  datapath = '/home/aeurai/Data/'
elif 'uraiae' in usr: # ALICE
  datapath = '/home/uraiae/data1/'
elif 'urai' in usr:  # mbp laptop
  datapath = '/Users/urai/Data/projects/0/neurodec/Data/MEG-PL/'

# MEG_HDDMnn folder in /home/uraiae/data
datasets = ['MEG_HDDMnn', 'sim_Xno_Mno']

# select only this dataset
if isinstance(opts.dataset, str):
    opts.dataset = [opts.dataset]
dataset = datasets[opts.dataset]

# ============================================ #
# READ INPUT ARGUMENTS; model
# ============================================ #

models = ['ddm_prevresp', #0
          'angle_prevresp', #1
          'weibull_prevresp', #2
          'weibull_twohist', #3
          'weibull_allhist', 
          'weibull_ips23_refwin', #5
          'weibull_ips23_resid', #6
          'weibull_ips23_prevresp', #7
          'weibull_motor_prestimwin', #8
          'weibull_motor_stimwin', #9 
          'weibull_motor_prevresp', #10
          'weibull_allhist_prevresp',
          'weibull_allhist_bound', # 12
          'weibull_allhist_groupsplit',
          'weibull_allhist_groupint',
          'weibull_bound', #15
          'weibull_bound_prevchoice', # 16
          'weibull_ips23_prevresp_repeaters',
          'weibull_ips23_prevresp_alternators',
          'weibull_motor_prevresp_repeaters',
          'weibull_motor_prevresp_alternators',
          ]

if isinstance(opts.model, str):
    opts.model = [opts.model]
# select only this model
m = models[opts.model]

# ============================================ #
# GET DATA - smaller version of large 'flipped'
# dataset (to reduce I/O on ALICE)
# ============================================ #

csvfile = glob.glob(os.path.join(datapath, dataset, '*.csv'))
print(csvfile)
data = pd.read_csv(csvfile[0])
data.dropna(subset=['rt', 'response', 'stimulus'], inplace=True) # to avoid errors
# pprint.pprint(data.describe())

# MAKE A PLOT OF THE RT DISTRIBUTIONS PER ANIMAL
if not os.path.isfile(os.path.join(datapath, dataset, 'figures', 'rtdist.png')):
    # make a new folder if it doesn't exist yet
  if not os.path.exists(os.path.join(datapath, dataset, 'figures')):
      try:
        os.makedirs(os.path.join(datapath, dataset, 'figures'))
        print('creating directory %s' % os.path.join(datapath, dataset, 'figures'))
      except:
        pass

  g = sns.FacetGrid(data, col='subj_idx', col_wrap=8)
  g.map(sns.distplot, "rt", kde=False, rug=True)
  g.savefig(os.path.join(datapath, dataset, 'figures', 'rtdist.png'))

# ============================================ #
# FIT THE ACTUAL MODEL
# ============================================ #
  
starttime = time.time()

# regression model; slow but more precise
# if not os.path.isfile(os.path.join(datapath, dataset, m, 'group_traces.csv')):
print('starting model %s, %s'%(datapath, dataset))
hddmnn_funcs.run_model(data, m, os.path.join(datapath, dataset, m),
                 n_samples=25000, trace_id=opts.trace_id)

# HOW LONG DID THIS TAKE?
elapsed = time.time() - starttime
print( "Elapsed time for %s, trace %d: %f seconds\n" %(m, opts.trace_id, elapsed))
