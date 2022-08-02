"""
plot HDDMnn models that were fitted on ALICE
Anne Urai, Leiden University, 2022
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

import hddmnn_corrstats, hddmnn_funcs
sns.set(style='ticks')
hddmnn_funcs.seaborn_style()
import scipy as sp
from optparse import OptionParser
from scipy.stats import kde

# find path depending on location and dataset
usr = os.environ['USER']
if 'uraiae' in usr:  # alice
    #datapath = '/home/aeurai/Data/MEG_HDDM_all'
    datapath = '/home/uraiae/data/MEG_HDDMnn'
    plt.switch_backend('agg') # still plot
elif 'urai' in usr:  # mbp laptop
    # datapath = '/Users/urai/Data/projects/0/neurodec/Data/MEG-PL/MEG_HDDM_all_clean'
    datapath = '/Users/urai/Data/home/uraiae/data1/MEG_HDDMnn'


#%% which model fits best (without history)?

nohist_models = ['ddm_prevresp', 'angle_prevresp', 'weibull_prevresp']
mdcomps = pd.DataFrame()
for m in nohist_models:
    mdcomp = pd.read_csv(os.path.join(datapath, m, 'model_comparison.csv'))
    mdcomp['model'] = m
    print(m + ' DIC: ' + str(mdcomp.dic[0]))
    mdcomps = mdcomps.append(mdcomp)
mdcomps['hue'] = mdcomps.dic < 55000

plt.close('all')
g, ax = plt.subplots(nrows=1, ncols=1, figsize=(2.1,1.3))
sns.barplot(data=mdcomps, x='model', y='dic', ax=ax, facecolor=".8", edgecolor=".2")
ax.set_xticklabels(['static', 'linear\ncollapse', 'weibull\ncollapse'], rotation=0, va='top')
## ax.legend_.remove()
ax.set(xlabel='', ylabel='DIC')
sns.despine()
plt.tight_layout()
plt.savefig(os.path.join(datapath, 'figures', 
                             'modelcomp.pdf'), facecolor='white')

# a narrower one for the main figure inset
plt.close('all') 
g, ax = plt.subplots(nrows=1, ncols=1, figsize=(1.7,1.3))
ax.bar(np.arange(3), mdcomps.dic, facecolor="1", edgecolor=".2", width=0.5)
ax.bar(2, mdcomps.dic.values[-1], facecolor="teal", edgecolor=".2", width=0.5)
plt.xticks(np.arange(3), ['static', 'linear\ncollapse', 'weibull\ncollapse'], rotation=-40, va='top')
## ax.legend_.remove()
ax.set(xlabel='', ylabel='')
sns.despine()
plt.tight_layout()
plt.savefig(os.path.join(datapath, 'figures',
                             'modelcomp_small.pdf'), facecolor='lightsteelblue')

#%% ============================================ #
# LOOK AT PARAMTERS OF NEURAL MODELS
# ============================================ #

models = ['ddm_nohist',
          'ddm_prevresp',
          'ddm_ips23gamma',
          'ddm_ips01alpha',
          'ddm_motorbeta',
          'ddm_twohist',
          'ddm_allhist', #6
          'angle_nohist',
          'angle_prevresp',
          'angle_ips23gamma',
          'angle_ips01alpha',
          'angle_motorbeta',
          'angle_twohist',
          'angle_allhist', #13
          'angle_allhist_bound',
          'weibull_nohist',
          'weibull_allhist',
          'ddm_allhist_groupsplit',
          'angle_allhist_groupsplit',
          'weibull_allhist_groupsplit',
          'ddm_allhist_groupint',
          'angle_allhist_groupint',
          'weibull_allhist_groupint',
          ]

# models = ['weibull_prevresp']

# models below are going into the final figures
models = ['ddm_prevresp',
          'angle_prevresp',
          'weibull_prevresp', # suppfig 1
          'weibull_allhist', # main figure 7
          'weibull_ips23_prevresp',
          'weibull_ips23_refwin',
          'weibull_ips23_resid',
          'weibull_motor_prestimwin', #7
          'weibull_motor_stimwin',
          'weibull_motor_prevresp',
          'weibull_bound',
          'weibull_bound_prevchoice',
          'weibull_allhist_groupsplit',
          'weibull_allhist_groupint',
          'weibull_allhist_prevresp',
          'weibull_allhist_bound',
          ]

#%% =========================== #
# unified plot
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
    az.plot_posterior(xdata, hdi_prob=0.95, ref_val=0)
    plt.savefig(os.path.join(datapath, 'figures', '%s_arviz.pdf'%m),
                facecolor='white')
    
    # make a nicer overview plot
    trace_melt = trace[[c for c in trace.columns if not '_std' in c 
                        and not 'Unnamed' in c]].melt(var_name='column')
    
    g = sns.FacetGrid(data=trace_melt, 
                      col = 'column', col_wrap = 5,
                      sharex=False, sharey=False)
    g.map(hddmnn_funcs.distfunc, "value")
    g.set_titles(col_template="{col_name}")
    sns.despine()
    plt.tight_layout(rect=[0, 0.03, 1, 0.95])
    g.savefig(os.path.join(datapath, 'figures',
                                 '%s_hddmnn.pdf' % (m)), facecolor='white')


#%% =========================== #
# single panel plot
# =========================== #

for ridx, m in enumerate(models):

    plt.close('all')

    # m = freqs + '_' + r + '_' + wins + 'win'
    if not os.path.exists(os.path.join(datapath, m, 'group_traces.csv')):
        continue # skip if not present

    trace = pd.read_csv(os.path.join(datapath, m, 'group_traces.csv'))

    # # use arviz to get the HDI
    # trace["chain"] = 0
    # trace["draw"] = np.arange(len(trace), dtype=int)
    # trace = trace.set_index(["chain", "draw"])
    # xdata = xr.Dataset.from_dataframe(trace)

    print(m)

    for vidx, var in enumerate(trace.columns):
        if var.startswith('z_'):
            color = 'coral'
        elif var.startswith('v_'):
            color = 'firebrick'
        else:
            color = 'darkgrey'

        fig, ax = plt.subplots(nrows=1, ncols=1, figsize=(1.5, 1.2),
                               sharex=False, sharey=False)

        # 1. group distribution with individual datapoints
        print(var)

        # hdi = az.hdi(xdata, hdi_prob=0.95, var_names=var)
        # print(pval)
        pval = np.min([np.mean(trace[var] > 0), np.mean(trace[var] < 0)])

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
        if pval < 0.001:
            txt = "***"
        elif pval < 0.01:
            txt = "**"
        elif pval < 0.05:
            txt = "*"
        else:
            txt = ''
            
        if pval > 0.0000001:
            ax.text(trace[var].mean(), np.min(ax.get_ylim()) +
                      0.1 * ( np.max(ax.get_ylim()) - np.min(ax.get_ylim())),
                      txt, fontsize=10, fontweight='bold', ha='center',
                      color='k')
        
        # add the p-value on top, position in the panel manually
        txt = "p = {:.4f}".format(pval)
        if pval < 0.0001:
            txt = np.format_float_scientific(pval, precision = 2, exp_digits=3)
        
        # plot above the distribution
        if m == 'weibull_allhist':
            print(m, var, txt)
        else:
            if pval > 0.0000001: # dont show this when it's 100% significant
                ax.text(trace[var].mean(), np.max(ax.get_ylim()),
                      txt, fontsize=6, ha='center',
                      color='.15')
   
        xlims = ax.get_xlim()
        if not color == 'darkgrey':
            new_xlim = [-np.max(np.abs(xlims)), np.max(np.abs(xlims))]
        else: 
            new_xlim = xlims

        # if 'win' in var:
        #     ax.set(xlim=[-0.15, 0.15], ylim=[0, 48])
        #     # if trace[var].mean() < -0.05:
        #     #     ax.set(xlim=[-0.2, 0.06])
        ax.tick_params(axis='both', labelsize=6)
        ax.set(xlabel='', ylabel='', yticklabels=[],
               xlim=new_xlim)
        sns.despine()
        plt.tight_layout()
        fig.savefig(os.path.join(datapath, 'figures',
                                 'hddmnn_post_%s_%s.pdf' % (m, var)))

        # ===================== #

    # plt.close('all')
    # xdata = xr.Dataset.from_dataframe(trace)
    # az.plot_posterior(xdata, textsize=14, hdi_prob=0.95,
    #                   var_names=['win'], filter_vars="like", ref_val=0)
    # plt.savefig(os.path.join(datapath, 'figures',
    #                          'hdi_%s.pdf' % (m)), facecolor='white')
#

#%% ===== correlation with p(repeat)

models = ['weibull_prevresp']
data = pd.read_csv(os.path.join(datapath, 'data_meg_hddmnn.csv'))
rep = data.groupby(['subj_idx'])['repeat'].mean().reset_index()

for m in models:
    # now load in the models we need
    md = pd.read_csv(os.path.join(datapath, m, 'results_combined.csv'))
    md_wide = hddmnn_funcs.results_long2wide(md, name_col='index', val_col='mean')
    md_wide['subj_idx'] = md_wide['subj_idx'].astype(int)
    
    # COMPUTE THE SAME THING FROM HDDM COLUMN NAMES
    md_wide = pd.merge(md_wide, rep, on='subj_idx') # add repetition behavior
    
    fig, ax = plt.subplots(ncols=2, nrows=1, sharey=True, sharex=False, figsize=(3.2, 1.8))
    hddmnn_funcs.corrplot(x=md_wide.z_prevresp, y=md_wide.repeat, subj=md_wide.repeat, ax=ax[0])
    ax[0].set(xlabel='', ylabel='P(repeat)')
    hddmnn_funcs.corrplot(x=md_wide.v_prevresp, y=md_wide.repeat, subj=md_wide.repeat, ax=ax[1])
    ax[1].set(xlabel='', ylabel=' ', yticks=[0.4, 0.5, 0.6])
    
    # # ADD STEIGERS TEST ON TOP
    # x = repeat, y = zshift, z = dcshift
    tstat, pval = hddmnn_corrstats.dependent_corr(sp.stats.spearmanr(md_wide.z_prevresp,
                                                                    md_wide.repeat,
                                                                    nan_policy='omit')[0],
                                            sp.stats.spearmanr(md_wide.v_prevresp,
                                                              md_wide.repeat, nan_policy='omit')[0],
                                            sp.stats.spearmanr(md_wide.z_prevresp,
                                                              md_wide.v_prevresp, nan_policy='omit')[0],
                                            len(md_wide),
                                            twotailed=True, conf_level=0.95, method='steiger')
    deltarho = sp.stats.spearmanr(md_wide.z_prevresp, md_wide.repeat, nan_policy='omit')[0] - \
                sp.stats.spearmanr(md_wide.v_prevresp, md_wide.repeat, nan_policy='omit')[0]
    if pval < 0.0001:
        fig.suptitle(r'$\Delta\rho$ = %.3f, p = < 0.0001'%(deltarho), y=0.9, fontsize='small', fontstyle='italic')
    else:
        fig.suptitle(r'$\Delta\rho$ = %.3f, p = %.4f' % (deltarho, pval), fontsize=8)
        
    sns.despine(trim=True)
    plt.tight_layout()
    fig.savefig(os.path.join(datapath, 'figures', 'weibull_prevresp_correlation.pdf'))

