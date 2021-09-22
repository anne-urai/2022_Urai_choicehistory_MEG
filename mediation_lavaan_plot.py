#%%
import numpy as np
import pandas as pd
import os
import seaborn as sns
import matplotlib.pyplot as plt
from hddm_funcs_plot import results_long2wide, seaborn_style, corrplot
sns.set(style='ticks')
seaborn_style()
import pingouin as pg

#%% GET DATA
usr = os.environ['USER']
if 'aeurai' in usr:  # lisa
    datapath = '/home/aeurai/Data/MEG_HDDM'
elif 'urai' in usr:  # mbp laptop
    datapath = '/Users/urai/Data/projects/0/neurodec/Data/MEG-PL/'

#%%

# add repetition probability
data = pd.read_csv(os.path.join(datapath, 'CSV', 'allsubjects_megall_4hddm_norm_flip.csv'))
rep = data.groupby(['subj_idx'])['repeat'].mean().reset_index()
rep['repeaters'] = (rep['repeat'] > 0.5)

# add lavaan output
for trials in ['all', 'error', 'correct']:

    df_lavaan = pd.read_csv(os.path.join(datapath, 'CSV',
                                     'mediation', 'lavaan_threemediators_%s.csv'%trials))
    df_lavaan2 = df_lavaan.pivot_table(values='est', index='subj_idx', columns='label').reset_index()

    # merge these different ones
    df = pd.merge(df_lavaan2, rep, on='subj_idx')

    # # plot all of them
    # plt.close('all')
    # g = sns.PairGrid(df, palette='PuBu', height=1.5)
    # g.map(corrplot, subj=df['repeat'])  # .set(xlim=[-0.5, 0.5], ylim=[-0.5, 0.5])
    # g.savefig(os.path.join(datapath, 'Figures', 'lavaan_pairplot.pdf'))

    #%%
    # ============ plot each parameter + stats
    for v in df.columns:

        # stats
        # hack pingouin to avoid numerical underflow: compute CI based on larger values, then divide again below (
        # doesn't affect ttest or mean)
        ttest_against_zero = pg.ttest(df[v] * 10000, 0)
        corr_with_repeat = pg.corr(df[v], df['repeat'], method='spearman')

        #### plot
        plt.close('all')
        ## 1. group distribution with individual datapoints
        fig, ax = plt.subplots(nrows=2, ncols=1, figsize=(2, 3), gridspec_kw={'height_ratios': [1, 2]},
                               sharex=False, sharey=False)

        # sns.pointplot(data=df, x=v, ax=ax[0], color='darkgrey', join=False)
        if ttest_against_zero['p-val'].item() < 0.05:
            plotvars = {'mec': 'w', 'mfc': '0.2', 'ms': 5}
        else:
            plotvars = {'mec': '0.2', 'mfc': 'w', 'ms': 4}

        xerr = np.array(df[v].mean() - ttest_against_zero['CI95%'].item()[0] / 10000,
                        ttest_against_zero['CI95%'].item()[1] / 10000 - df[v].mean()).T
        ax[0].errorbar(x=df[v].mean(), y=0, yerr=None,
                       xerr=xerr, marker='o', color='0.2', **plotvars)
        # ax[0].axis('off')
        ax[0].axvline(0, color='.15', zorder=-100, ymin=0.4, ymax=0.6)

        # do stats on the posterior distribution
        txt = r"t({}) = {:.3f}".format(ttest_against_zero['dof'].item(), ttest_against_zero['T'].item()) + "\n" + \
              "p = {:.4f}".format(ttest_against_zero['p-val'].item())
        if ttest_against_zero['p-val'].item() < 0.0001:
            txt = r"t({}) = {:.3f}".format(ttest_against_zero['dof'].item(),
                                           ttest_against_zero['T'].item()) + "\n" + "p < 0.0001"

        ax[0].text(0.1, 0.8, txt, fontsize='small', transform=ax[0].transAxes, fontstyle='italic')
        ax[0].set(ylabel='Point\nestimates', xlabel=' ', yticklabels=' ',
                  xlim=[-np.max(np.abs(ax[0].get_xlim()) * 1.1), np.max(np.abs(ax[0].get_xlim()) * 1.1)])

        # compute pvalue from correlation
        if corr_with_repeat['p-val'].item() < 0.05:
            sns.regplot(x=df[v], y=df['repeat'], data=df, ax=ax[1],
                        color='.15', ci=None, scatter=False, truncate=True)
        sns.scatterplot(x=v, y='repeat', data=df, ax=ax[1],
                        hue='repeat', marker='o', palette='PuBu', legend=False, zorder=-100)

        # annotate with the correlation coefficient + n-2 degrees of freedom
        txt = r"$\rho$({}) = {:.3f}".format(corr_with_repeat['n'].item() - 2, corr_with_repeat['r'].item()) + "\n" + \
              "p = {:.4f}".format(corr_with_repeat['p-val'].item())
        if corr_with_repeat['p-val'].item() < 0.0001:
            txt = r"$\rho$({}) = {:.3f}".format(corr_with_repeat['n'].item() - 2,
                                                corr_with_repeat['r'].item()) + "\n" + "p < 0.0001"
        ax[1].annotate(txt, xy=(0.1, .1), xycoords='axes fraction', fontsize='small', fontstyle='italic')
        ax[1].set(ylabel='P(repeat)', xlabel=v, ylim=[0.4, 0.62],
                  xlim=[-np.max(np.abs(ax[1].get_xlim()) * 1.1), np.max(np.abs(ax[1].get_xlim()) * 1.1)])
        # ax[0].set_xlim(tuple(i * 0.1 for i in ax[1].get_xlim()))
        sns.despine()
        plt.tight_layout()
        fig.savefig(os.path.join(datapath, 'figures', 'lavaan_3mediators_%s.pdf' %v), facecolor='white')


    #%% one plot for the main figure 3b
    df['x'] = 0
    ylims = [[0.005, 0.005, 0.005, 0.07], [0.15, 0.15, 0.15, 0.15, 0.15, 0.15]]

    for vsidx, varsets in enumerate([['indirect_gamma',  'indirect_alpha', 'indirect_betalat', 'direct'],
                    ['a1', 'a2', 'a3', 'b1', 'b2', 'b3']]):

        fig, ax = plt.subplots(nrows=1, ncols=len(varsets), figsize=(len(varsets)*1.3, 2))
        for vidx, v in enumerate(varsets):

            # sns.swarmplot(y=v, x='x', data=df, hue='repeat',
            #               marker='.', palette='PuBu', edgecolor='w', zorder=-100,
            #               ax=ax[vidx])

            # now the summary
            ttest_against_zero = pg.ttest(df[v] * 10000, 0)
            if ttest_against_zero['p-val'].item() < 0.05:
                plotvars = {'mec': 'w', 'mfc': 'k', 'ms': 14}
            else:
                plotvars = {'mec': 'k', 'mfc': 'w', 'ms': 10}

            yerr = np.array(df[v].mean() - ttest_against_zero['CI95%'].item()[0] / 10000,
                            ttest_against_zero['CI95%'].item()[1] / 10000 - df[v].mean()).T
            ax[vidx].errorbar(y=df[v].mean(), x=0, yerr=yerr,
                              xerr=None, marker='.', color='k', **plotvars)
            ax[vidx].axhline(0, linestyle=':', color='.15', zorder=-100)
            ax[vidx].set(ylim=[-ylims[vsidx][vidx], ylims[vsidx][vidx]],
                         xlim=[-0.1, 0.1],
            #    ylim=[-np.max(np.abs(df[v])) * 1.1, np.max(np.abs(df[v])) * 1.1],
                         xlabel='', xticklabels=[],
                         ylabel=v)
            #ax[vidx].legend_.remove()

            # do stats on the posterior distribution
            pval = ttest_against_zero['p-val'].item()
            txt = "p = {:.4f}".format(pval)
            if pval < 0.001:
                txt = "***"
            elif pval < 0.01:
                txt = "**"
            elif pval < 0.05:
                txt = "*"
            else:
                txt = ''

            # # add t-statistic
            # txt = r"t({}) = {:.3f}".format(ttest_against_zero['dof'].item(),
            #                                ttest_against_zero['T'].item()) + "\n" + \
            #       "p = {:.4f}".format(ttest_against_zero['p-val'].item())
            # if  < 0.0001:
            #     txt = r"t({}) = {:.3f}".format(ttest_against_zero['dof'].item(),
            #                                    ttest_against_zero['T'].item()) + "\n" + "p < 0.0001"

            ax[vidx].text(0.5, 0.85, txt, fontsize='small', transform=ax[vidx].transAxes, ha='center',
                          fontweight='bold')
            ax[vidx].tick_params(axis='x', colors='w')

        sns.despine(trim=True)
        plt.tight_layout()
        plt.show()
        fig.savefig(os.path.join(datapath,
                                 'figures', 'lavaanMulti_3mediators_%s_v%s.pdf'%(trials, vsidx)),
                    facecolor='white')


# ====================================================== #
#%% a new figure with correct and error side-by-side (+ stats)
# ====================================================== #

df_lavaan_corr = pd.read_csv(os.path.join(datapath, 'CSV',
                                 'mediation', 'lavaan_threemediators_%s.csv'%'correct'))
df_lavaan2_corr = df_lavaan_corr.pivot_table(values='est', index='subj_idx', columns='label').reset_index()

df_lavaan_err = pd.read_csv(os.path.join(datapath, 'CSV',
                                 'mediation', 'lavaan_threemediators_%s.csv'%'error'))
df_lavaan2_err = df_lavaan_err.pivot_table(values='est', index='subj_idx', columns='label').reset_index()

# merge these different ones
df = pd.merge(df_lavaan2_corr, df_lavaan2_err, on='subj_idx',
              suffixes=("_correct", "_error"))

x = [-0.1, 0.1]
ylims = [[0.01, 0.01, 0.01, 0.1]]

for vsidx, varsets in enumerate([['indirect_gamma', 'indirect_alpha', 'indirect_betalat', 'direct']]):

    fig, ax = plt.subplots(nrows=1, ncols=len(varsets), figsize=(len(varsets) * 1.3, 2))
    for vidx, v in enumerate(varsets):

        for pfbidx, prevfb in enumerate(['_correct', '_error']):
            cols = ['darkgreen', 'darkred']

            # now the summary
            ttest_against_zero = pg.ttest(df[v + prevfb] * 10000, 0)
            if ttest_against_zero['p-val'].item() < 0.05:
                plotvars = {'mec': 'w', 'mfc': cols[pfbidx], 'ms': 14}
            else:
                plotvars = {'mec': cols[pfbidx], 'mfc': 'w', 'ms': 10}

            yerr = np.array(df[v + prevfb].mean() - ttest_against_zero['CI95%'].item()[0] / 10000,
                            ttest_against_zero['CI95%'].item()[1] / 10000 - df[v + prevfb].mean()).T
            ax[vidx].errorbar(y=df[v + prevfb].mean(), x=x[pfbidx], yerr=yerr,
                              xerr=None, marker='.', color=cols[pfbidx], **plotvars)
            ax[vidx].axhline(0, linestyle=':', color='.15', zorder=-100)
            ax[vidx].set(ylim=[-ylims[vsidx][vidx], ylims[vsidx][vidx]],
                         xlim=[-0.3, 0.3], xticks=x,
                         #    ylim=[-np.max(np.abs(df[v])) * 1.1, np.max(np.abs(df[v])) * 1.1],
                         xlabel='',  ylabel=v)
            ax[vidx].set_xticklabels(['correct', 'error'], rotation=-30)
            [t.set_color(i) for (i, t) in zip(cols, ax[vidx].xaxis.get_ticklabels())]

            # do stats on the posterior distribution
            pval = ttest_against_zero['p-val'].item()
            if pval < 0.001:
                txt = "***"
            elif pval < 0.01:
                txt = "**"
            elif pval < 0.05:
                txt = "*"
            else:
                txt = ''
            ax[vidx].text(x[pfbidx], ttest_against_zero['CI95%'].item()[1] / 10000 * 1.1,
                          txt,
                          fontsize='small', ha='center',
                          fontweight='bold', color=cols[pfbidx])

        # paired ttest between correct and error
        ttest_paired = pg.ttest(df[v + '_correct'] * 10000, df[v + '_error'] * 10000)
        pval = ttest_paired['p-val'].item()
        if pval < 0.001:
            txt = "***"
        elif pval < 0.01:
            txt = "**"
        elif pval < 0.05:
            txt = "*"
        else:
            txt = ''
        ax[vidx].text(0.5, 1, txt,
                      fontsize='small', transform=ax[vidx].transAxes, ha='center',
                      fontweight='bold', color='k')
    sns.despine(trim=True)
    plt.tight_layout()
    plt.show()
    fig.savefig(os.path.join(datapath,
                             'figures', 'lavaanMulti_correctVerror.pdf'),
                facecolor='white')

