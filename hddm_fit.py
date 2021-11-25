"""
fit HDDM model, with history terms, to data from IBL mice
Anne Urai, 2019, CSHL

"""

# ============================================ #
# GETTING STARTED
# ============================================ #

import matplotlib as mpl
mpl.use('Agg')  # to still plot even when no display is defined
from optparse import OptionParser
import pandas as pd
import os, time

# import HDDM functions, defined in a separate file
import hddm_funcs

# more handy imports
import hddm
import seaborn as sns
sns.set()

# read inputs
usage = "HDDM_run.py [options]"
parser = OptionParser(usage)
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
elif 'urai' in usr:  # mbp laptop
  datapath = '/Users/urai/Data/projects/0/neurodec/Data/MEG-PL/HDDM'

datasets = ['MEG_HDDM_all_clean']

# select only this dataset
if isinstance(opts.dataset, str):
    opts.dataset = [opts.dataset]
dataset = datasets[opts.dataset]

# ============================================ #
# READ INPUT ARGUMENTS; model
# ============================================ #

models = ['nohist',  #0
          'prevchoice_z',
          'prevchoice_dc',
          'prevchoice_dcz',
          'alpha_ips01stim_vz',  #4
          'gamma_ips23stim_vz',  #5
          'beta_motor_vz', # 6
          'beta_motor_prestim_vz', # 7
          'gammaresid_ips23stim_vz',
          'alpharesid_ips01stim_vz',
          'gamma_ips23prestim_vz', 
          'alpha_ips01prestim_vz',
          ]

if isinstance(opts.model, str):
    opts.model = [opts.model]
# select only this model
m = models[opts.model]

print(opts)
print(m)

# ============================================ #
# GET DATA
# ============================================ #

data = pd.read_csv(os.path.join(datapath, dataset, 'allsubjects_megall_4hddm_norm_flip.csv'))

# MAKE A PLOT OF THE RT DISTRIBUTIONS PER ANIMAL
if not os.path.isfile(os.path.join(datapath, dataset, 'figures', 'rtdist.png')):

    if not os.path.exists(os.path.join(datapath, dataset, 'figures')):
        try:
          os.makedirs(os.path.join(datapath, dataset, 'figures'))
        except:
          pass

    g = sns.FacetGrid(data, col='subj_idx', col_wrap=8)
    g.map(sns.distplot, "rt", kde=False, rug=True)
    g.savefig(os.path.join(datapath, dataset, 'figures', 'rtdist.png'))

# ============================================ #
# FIT THE ACTUAL MODEL
# ============================================ #

# gsq fit, quick
# md = hddm_funcs.run_model_gsq(data, m, datapath)

starttime = time.time()

# regression model; slow but more precise
if not os.path.isfile(os.path.join(datapath, dataset, m, 'results_combined.csv')):
    print('starting model %s, %s'%(datapath, dataset))
    hddm_funcs.run_model(data, m, os.path.join(datapath, dataset, m),
                         n_samples=10000, force=False, trace_id=opts.trace_id)

# ============================================ #
# CONCATENATE across chains
# ============================================ #

if opts.trace_id == 14 and not os.path.exists(os.path.join(datapath, dataset, m,
                                                      'model_comparison_avg.csv')):

    # wait until all the files are present
    filelist = []
    for t in range(15):
        filelist.append(os.path.join(datapath, dataset, m, 'modelfit-md%d.model' % t))

    print(filelist)
    while True:
        if all([os.path.isfile(f) for f in filelist]):
            break
        else:  # wait
            print("waiting for files")
            # raise ValueError('Not all files present')
            time.sleep(60)

    # concatenate the different chains, will save disk space
    hddm_funcs.concat_models(os.path.join(datapath, dataset), m)

# HOW LONG DID THIS TAKE?
elapsed = time.time() - starttime
print( "Elapsed time for %s, trace %d: %f seconds\n" %(m, opts.trace_id, elapsed))


# also sample posterior predictives (will only do if doesn't already exists
# hddm_funcs.posterior_predictive(os.path.join(datapath, d, m), n_samples=100)