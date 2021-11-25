"""
plot HDDM models, without neural data, on MEG dataset
replicate main results from eLife
Anne Urai, 2020 CSHL

"""

#%% ============================================ #
# GETTING STARTED
# ============================================ #
import matplotlib as mpl
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
import numpy as np
import os
import pingouin as pg
import arviz as az
import xarray as xr

from hddm_funcs_plot import results_long2wide, seaborn_style
sns.set(style='ticks')
seaborn_style()
import scipy as sp
from optparse import OptionParser
from scipy.stats import kde

# find path depending on location and dataset
usr = os.environ['USER']
if 'aeurai' in usr:  # lisa
    datapath = '/home/aeurai/Data/MEG_HDDM_all'
    plt.switch_backend('agg') # still plot
elif 'urai' in usr:  # mbp laptop
    datapath = '/Users/urai/Data/projects/0/neurodec/Data/MEG-PL/MEG_HDDM_all_clean'

 #%% ============================================ #
# LOOK AT PARAMTERS OF NEURAL MODELS
# ============================================ #


models = ['gamma_ips23_stimwin',
          'alpha_ips01_stimwin_resid',
          'beta_3motor_lat_refwin']

# =========================== #
# single panel plot
# =========================== #

for ridx, m in enumerate(models):

    plt.close('all')

    # m = freqs + '_' + r + '_' + wins + 'win'
    if not os.path.exists(os.path.join(datapath, m, 'group_traces.csv')):
        continue # skip if not present

    trace = pd.read_csv(os.path.join(datapath, m, 'group_traces.csv'))

    # use arviz to get the HDI
    trace["chain"] = 0
    trace["draw"] = np.arange(len(trace), dtype=int)
    trace = trace.set_index(["chain", "draw"])
    xdata = xr.Dataset.from_dataframe(trace)

    print(m)
    # print(hdi)

    for vidx, var in enumerate(trace.columns):
        if var.startswith('z_'):
            color = 'coral'
        elif var.startswith('v_'):
            color = 'firebrick'
        else:
            color = 'darkgrey'

        fig, ax = plt.subplots(nrows=1, ncols=1, figsize=(1.5, 1.5),
                               sharex=False, sharey=False)

        # 1. group distribution with individual datapoints
        print(var)
        pval = np.min([np.mean(trace[var] > 0), np.mean(trace[var] < 0)])
        hdi = az.hdi(xdata, hdi_prob=0.95, var_names=var)
        # print(pval)
        if pval < 0.05:
            fill = True
        else:
            fill = False

        # now the distribution
        sns.distplot(trace[var], kde=True, hist=True, rug=False,
                     color=color, ax=ax, vertical=False, norm_hist=True,
                     kde_kws={'shade': fill},
                     hist_kws={"histtype": "step", "linewidth": 0})
        ax.axvline(0, color='.15', zorder=0, ymin=0, ymax=0.9)

        # do stats on the posterior distribution
        txt = "p = {:.4f}".format(pval)
        if pval < 0.001:
            txt = "***"
        elif pval < 0.01:
            txt = "**"
        elif pval < 0.05:
            txt = "*"
        else:
            txt = ''

        ax.text(trace[var].mean(), np.min(ax.get_ylim()) +
                     0.1 * ( np.max(ax.get_ylim()) - np.min(ax.get_ylim())),
                      txt, fontsize=10, fontweight='bold', ha='center',
                      color='k')

        if 'win' in var:
            ax.set(xlim=[-0.06, 0.06], ylim=[0, 48])
            if trace[var].mean() < -0.05:
                ax.set(xlim=[-0.2, 0.06])
        ax.tick_params(axis='both', labelsize=6)
        ax.set(xlabel=' ')

        sns.despine()
        plt.tight_layout(rect=[0, 0.03, 1, 0.95])
        fig.savefig(os.path.join(datapath, 'figures',
                                 'hddmdistr_%s_%s.pdf' % (m, var)), facecolor='white')

        # ===================== #

    # plt.close('all')
    # xdata = xr.Dataset.from_dataframe(trace)
    # az.plot_posterior(xdata, textsize=14, hdi_prob=0.95,
    #                   var_names=['win'], filter_vars="like", ref_val=0)
    # plt.savefig(os.path.join(datapath, 'figures',
    #                          'hdi_%s.pdf' % (m)), facecolor='white')
#
#