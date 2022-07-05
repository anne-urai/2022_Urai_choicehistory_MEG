import pandas as pd
import numpy as np
import scipy as sp
import time, os
import matplotlib as mpl
mpl.use('Agg')  # to still plot even when no display is defined
import matplotlib.pyplot as plt
import pingouin as pg
import seaborn as sns
import arviz as az # for posterior plots
import xarray as xr

# ============================================ #
# define some functions
# ============================================ #

def corrplot(x, y, subj=[], **kwargs):
    
    if 'ax' in kwargs.keys():
        ax = kwargs['ax']
    else:
        ax = plt.gca()
    
    # compute pvalue from correlation
    corr_with_repeat = pg.corr(x, y, method='spearman')
    if corr_with_repeat['p-val'].item() < 0.01:
        sns.regplot(x=x, y=y,
                    color='darkgrey', ci=None, scatter=False, truncate=True,
                    ax=ax)
    sns.lineplot(x=x, y=y, hue=subj, linestyle='',
                    marker='o', legend=False, zorder=-100, 
                    palette='PuOr',hue_norm=(0.4,0.6),
                    ax=ax)

    # annotate with the correlation coefficient + n-2 degrees of freedom
    txt = r"$\rho$({}) = {:.3f}".format(corr_with_repeat['n'].item() - 2, corr_with_repeat['r'].item()) + "\n" + \
          "p = {:.4f}".format(corr_with_repeat['p-val'].item())
    if corr_with_repeat['p-val'].item() < 0.0001:
        txt = r"$\rho$({}) = {:.3f}".format(corr_with_repeat['n'].item() - 2,
                                            corr_with_repeat['r'].item()) + "\n" + "p < 0.0001"
    ax.annotate(txt, xy=(0.1, .9), xycoords='axes fraction', fontsize='x-small', fontstyle='italic')


def distfunc(x, **kws):
    
    if 'ax' in kws.keys():
        ax = kws['ax']
    else:
        ax = plt.gca()
    
    # 1. group distribution with individual datapoints
    pval = np.min([np.mean(x > 0), np.mean(x < 0)])
    # hdi = az.hdi(xdata, hdi_prob=0.95, var_names=var)
    # print(pval)
    if pval < 0.05:
        fill = True
    else:
        fill = False
    
    # now the distribution
    sns.histplot(x, ax=ax, element="step",
                 fill=fill)
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
    txt = "p = {:.4f}".format(pval)
    
    ax.text(x.mean(), np.min(ax.get_ylim()) +
                 0.1 * ( np.max(ax.get_ylim()) - np.min(ax.get_ylim())),
                  txt, fontsize=10, fontweight='bold', ha='center',
                  color='k')

def seaborn_style():
    """
    Set seaborn style for plotting figures
    """

    sns.set(style="ticks", context="paper",
            font="Arial",
            rc={"font.size": 9,
                "axes.titlesize": 9,
                "axes.labelsize": 9,
                "lines.linewidth": 1,
                "xtick.labelsize": 7,
                "ytick.labelsize": 7,
                "savefig.transparent": True,
                "xtick.major.size": 2.5,
                "ytick.major.size": 2.5,
                "xtick.minor.size": 2,
                "ytick.minor.size": 2,
                })
    mpl.rcParams['pdf.fonttype'] = 42
    mpl.rcParams['ps.fonttype'] = 42
    
    
def run_model(data, modelname, mypath, n_samples=1000, 
              trace_id=0):

    import hddm, kabuki
    from hddmnn_modelspec import make_model # specifically for HDDMnn models

    print('HDDM version: ', hddm.__version__)
    print('Kabuki version: ', kabuki.__version__)


    # get the model
    m = make_model(data, modelname)
    time.sleep(trace_id) # to avoid different jobs trying to make the same folder

    # make a new folder if it doesn't exist yet
    if not os.path.exists(mypath):
        try:
        	os.makedirs(mypath)
        	print('creating directory %s' % mypath)
        except:
        	pass

    print("begin sampling") # this is the core of the fitting
    m.sample(n_samples, burn = np.max([n_samples/10, 100]))

    print("save model comparison indices")
    df = dict()
    df['dic'] = [m.dic]
    df['aic'] = [aic(m)]
    df['bic'] = [bic(m)]
    df2 = pd.DataFrame(df)
    df2.to_csv(os.path.join(mypath, 'model_comparison.csv'))
    
    # save useful output
    print("saving summary stats")
    results = m.gen_stats().reset_index()  # point estimate for each parameter and subject
    results.to_csv(os.path.join(mypath, 'results_combined.csv'))

    print("saving traces")
    # get the names for all nodes that are available here
    group_traces = m.get_group_traces()
    group_traces.to_csv(os.path.join(mypath, 'group_traces.csv'))

    # ============================================ #
    # make some plots
    # ============================================ #
    
    
    print('plotting posteriors')
    # https://hddm.readthedocs.io/en/latest/lan_tutorial.html#section-1-model-info-simulation-basic-plotting
    hddm.plotting.plot_posterior_predictive(model = m,
                                            save = True,
                                            path = mypath)
    
    # correlate with individual parameter estimates
    df_fit = hddm.utils.results_long2wide(results, 
        name_col='index', val_col='mean')
    df_fit['subj_idx'] = df_fit['subj_idx'].astype(np.int64)
    # repetition bias, choice bias, accuracy
    rep = data.groupby(['subj_idx'])[['repeat', 'response', 
                                        'correct']].mean().reset_index() 
    df = df_fit.merge(rep, on='subj_idx')
    # plot with seaborn
    g = sns.PairGrid(data=df, corner=True)
    g.map_lower(corrfunc)
    g.map_diag(sns.histplot)
    g.savefig(os.path.join(mypath, 'param_corrplot.png'))

    # # posterior plot for each variable
    # # https://github.com/hcp4715/hddm_docker/blob/master/example/HDDM_official_tutorial_ArviZ.ipynb
    # group_traces["chain"] = 0
    # group_traces["draw"] = np.arange(len(group_traces), dtype=int)
    # group_traces = group_traces.set_index(["chain", "draw"])
    # xdata = xr.Dataset.from_dataframe(group_traces)
    # az.plot_posterior(xdata, hdi_prob=0.95, ref_val=0)
    # plt.savefig(os.path.join(mypath, 'param_hdi.png'))

# ============================================ #
# MODEL COMPARISON INDICES
# ============================================ #

def aic(self):
    
    import hddm, kabuki
    from hddmnn_modelspec import make_model # specifically for HDDMnn models

    k = len(self.get_stochastics())
    try:
        logp = sum([x.logp for x in self.get_observeds()['node']])
        aic = 2 * k - 2 * logp
    except:
        aic = np.nan
    return aic


def bic(self):

    import hddm, kabuki
    from hddmnn_modelspec import make_model # specifically for HDDMnn models

    k = len(self.get_stochastics())
    n = len(self.data)
    try:
        logp = sum([x.logp for x in self.get_observeds()['node']])
        bic = -2 * logp + k * np.log(n)
    except:
        bic = np.nan    
    return bic


# ============================================ #
# https://github.com/anne-urai/hddm/blob/master/hddm/utils.py#L1021

def results_long2wide(md, name_col="Unnamed: 0", val_col='mean'):
    # Anne Urai, 2022: include a little parser that returns a more manageable output
    # can be used on full_parameter_dict from hddm_dataset_generators.simulator_h_c
    # or on the output of gen_stats()
    import re # regexp

    # recode to something more useful
    # 0. replace x_subj(yy).ZZZZ with x(yy)_subj.ZZZZ
    md["colname_tmp"] = [re.sub(".+\_subj\(.+\)\..+", ".+\(.+\)\_subj\..+", i) for i in list(md[name_col])]

    # 1. separate the subject from the parameter
    new = md[name_col].str.split("_subj.", n=1, expand=True)
    md["parameter"] = new[0]
    md["subj_idx"] = new[1]

    # only run this below if it's not a regression model!
    if not any(md[name_col].str.contains('Intercept', case=False)) \
        and not any(md[name_col].str.contains('indirect', case=False)):
        new = md["subj_idx"].str.split("\)\.", n=1, expand=True)
        # separate out subject idx and parameter value
        for index, row in new.iterrows():
            if row[1] == None:
                row[1] = row[0]
                row[0] = None

        md["parameter_condition"] = new[0]
        md["subj_idx"] = new[1]

        # pivot to put parameters as column names and subjects as row names
        md = md.drop(name_col, axis=1)
        md_wide = md.pivot_table(index=['subj_idx'], values=val_col,
                                 columns=['parameter', 'parameter_condition']).reset_index()
    else:
        # pivot to put parameters as column names and subjects as row names
        md = md.drop(name_col, axis=1)
        md_wide = md.pivot_table(index=['subj_idx'], values=val_col,
                                 columns=['parameter']).reset_index()
        
    return md_wide
