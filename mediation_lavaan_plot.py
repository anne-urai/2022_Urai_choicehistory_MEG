#%%
import numpy as np
import pandas as pd
import os
import seaborn as sns
import scipy as sp
import matplotlib.pyplot as plt
from hddmnn_funcs import seaborn_style
sns.set(style='ticks')
seaborn_style()
import pingouin as pg

#%% GET DATA
usr = os.environ['USER']
if 'aeurai' in usr:  # lisa
    datapath = '/home/aeurai/Data/MEG_HDDM'
elif 'urai' in usr:  # mbp laptop
    datapath = '/Users/urai/Data/projects/0/neurodec/Data/MEG-PL/'
    

# add repetition probability to split groups
data = pd.read_csv(os.path.join(datapath, 'MEG_HDDM_all_clean', 'allsubjects_megall_4hddm_norm_flip.csv'))
rep = data.groupby(['subj_idx'])['repeat'].mean().reset_index()
# rep['repeaters'] = (rep['repeat'] > 0.5)

# define groups, exclude P39
rep['repeaters'] = np.nan
rep.loc[rep.repeat < 0.5, 'repeaters'] = 0
rep.loc[rep.repeat > 0.5, 'repeaters'] = 1

#%%

# add lavaan output
for gridx, groups in enumerate(['repeaters', 'alternators', 'allsj']):
    group_markers = ['^', 'o', 's']
    
    plt.close('all')
    
    for trials in ['all', 'error', 'correct']:
    
        df_lavaan = pd.read_csv(os.path.join(datapath, 'CSV',
                                          'mediation', 'lavaan_threemediators_%s.csv'%trials))
        df_lavaan2 = df_lavaan.pivot_table(values='est', index='subj_idx', columns='label').reset_index()
        
        # merge these different ones
        df = pd.merge(df_lavaan2, rep, on='subj_idx')
        
        # subselect participants
        if groups == 'repeaters':
            df = df[df.repeaters == 1]
        elif groups == 'alternators':
            df = df[df.repeaters == 0]
        # else,  do nothing

    
        # one plot for the main figure 3b
        plt.close('all')
        df['x'] = 0
        ylims = [[0.005, 0.005, 0.005, 0.25], [0.15, 0.15, 0.15, 0.15, 0.15, 0.15]]
    
        for vsidx, varsets in enumerate([['indirect_gamma',  'indirect_alpha', 'indirect_betalat', 'direct'],
                        ['a1', 'a2', 'a3', 'b1', 'b2', 'b3']]):
    
            fig, ax = plt.subplots(nrows=1, ncols=len(varsets), figsize=(len(varsets)*1.3, 2))
            for vidx, v in enumerate(varsets):
    
                # now the summary
                ttest_against_zero = pg.ttest(df[v] * 10000, 0)
                if ttest_against_zero['p-val'].item() < 0.05:
                    plotvars = {'mec': 'w', 'mfc': 'k', 'ms': 8}
                else:
                    plotvars = {'mec': 'k', 'mfc': 'w', 'ms': 6}
    
                yerr = np.array(df[v].mean() - ttest_against_zero['CI95%'].item()[0] / 10000,
                                ttest_against_zero['CI95%'].item()[1] / 10000 - df[v].mean()).T
                ax[vidx].errorbar(y=df[v].mean(), x=0, yerr=yerr,
                                  xerr=None, marker=group_markers[gridx], color='k', **plotvars)
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
                    
                if df[v].mean() > 0:
                    star_y = ttest_against_zero['CI95%'].item()[1] /  10000 * 1.2
                else:
                    star_y = ttest_against_zero['CI95%'].item()[0] / 10000 * 1.6

                ax[vidx].text(0, star_y, txt, fontsize='small', ha='center',
                              fontweight='bold')
                ax[vidx].tick_params(axis='x', colors='w')
    
            sns.despine(trim=True)
            plt.tight_layout()
            plt.show()
            fig.savefig(os.path.join(datapath,
                                      'figures', 'lavaanMulti_3mediators_tr%s_v%s_gr%s.pdf'%(trials, vsidx, groups)),
                        facecolor='white')
            
# ====================================================== #
#%% another way: repeaters + alternators in 1 plot
# ====================================================== #

cmap1 = sns.color_palette('ch:s=.25,rot=-.25', n_colors=2)
cmap1 = sns.color_palette('PuOr', n_colors=7)
cmap = [(0.15,0.15,0.15), cmap1[1], cmap1[len(cmap1)-2]]

for trials in ['all', 'error', 'correct']:
    
    df_lavaan = pd.read_csv(os.path.join(datapath, 'CSV',
                                     'mediation', 'lavaan_threemediators_%s.csv'%trials))
    df_lavaan2 = df_lavaan.pivot_table(values='est', index='subj_idx', columns='label').reset_index()
    df_keep = pd.merge(df_lavaan2, rep, on='subj_idx')

    df['x'] = 0
    ylims = [[0.0051, 0.0051, 0.0051, 0.25], [0.15, 0.15, 0.15, 0.15, 0.15, 0.15]]

    for vsidx, varsets in enumerate([['indirect_gamma',  'indirect_alpha', 'indirect_betalat', 'direct'],
                                     ['a1', 'a2', 'a3', 'b1', 'b2', 'b3']]):
                
        plt.close('all')
        fig, ax = plt.subplots(nrows=1, ncols=len(varsets), figsize=(len(varsets)*1.3, 2))
        
        for gridx, groups in enumerate(['all', 'alternators', 'repeaters']):
            group_markers = ['s', 'o', '^']
            
            # merge these different ones
            df = pd.merge(df_lavaan2, rep, on='subj_idx')
        
            # subselect participants
            if groups == 'alternators':
                df = df[df.repeaters == 0]
                print('removing repeaters')
            elif groups == 'repeaters':
                df = df[df.repeaters == 1]
                print('keeping repeaters')
            elif groups == 'all':
                print('keeping all subjects in')
            
            for vidx, v in enumerate(varsets):
    
                # now the summary
                ttest_against_zero = pg.ttest(df[v] * 10000, 0)
                if ttest_against_zero['p-val'].item() < 0.05:
                    plotvars = {'mec': 'w', 'mfc': cmap[gridx], 'ms': 7}
                else:
                    plotvars = {'mec': cmap[gridx], 'mfc': 'w', 'ms': 5}
    
                yerr = np.array(df[v].mean() - ttest_against_zero['CI95%'].item()[0] / 10000,
                                ttest_against_zero['CI95%'].item()[1] / 10000 - df[v].mean()).T
                ax[vidx].errorbar(y=df[v].mean(), x=gridx, yerr=yerr,
                                  xerr=None, marker=group_markers[gridx], color=cmap[gridx], **plotvars)
                ax[vidx].axhline(0, linestyle='--', color='darkgrey', zorder=-100)
                ax[vidx].set(ylim=[-ylims[vsidx][vidx], ylims[vsidx][vidx]],
                             xlim=[-0.5, 2.2],
                              xlabel='', xticks=[0,1,2],
                              xticklabels=['all', 'alt', 'rep'],
                             ylabel=v)
                
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
                    
                if df[v].mean() > 0:
                    star_y = ttest_against_zero['CI95%'].item()[1] /  10000 * 1.2
                else:
                    star_y = ttest_against_zero['CI95%'].item()[0] / 10000 * 1.4

                ax[vidx].text(gridx, star_y, txt, fontsize='small', ha='center',
                              fontweight='bold', color=cmap[gridx])
                #ax[vidx].tick_params(axis='x', colors='w')
                
                # stats on the groupdiff
                if gridx == 2:
                    ttest2 = pg.ttest(df_keep.loc[df_keep.repeaters == 1, v], 
                                      df_keep.loc[df_keep.repeaters == 0, v], paired=False)
                    pval = ttest2['p-val'].item()
                    txt = "p = {:.4f}".format(pval)
                    if pval < 0.001:
                        txt = "-***-"
                    elif pval < 0.01:
                        txt = "-**-"
                    elif pval < 0.05:
                        txt = "-*-"
                    else:
                        txt = ''

                    # where to put this one?
                    if vidx == 0:
                        y_pos = star_y * 1.4
                    elif vidx == 3:
                        y_pos = star_y * 1.7
                    else:
                        y_pos = star_y * 1.5
        
                    ax[vidx].text(1.5, y_pos, txt, fontsize='small', ha='center', va='top',
                                  fontweight='bold', color='.1')
    
        sns.despine(trim=True)
        fig.tight_layout()
        fig.savefig(os.path.join(datapath, 'figures', 'lavaan_grcomp_tr%s_v%s.pdf'%(trials, vsidx)),
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
    
# ====================================================== #
#%% working memory mediation, as main figure 7
# ====================================================== #

cmap1 = sns.color_palette('ch:s=.25,rot=-.25', n_colors=2)
cmap1 = sns.color_palette('PuOr', n_colors=7)
cmap = [(0.15,0.15,0.15), cmap1[1], cmap1[len(cmap1)-2]]

for trials in ['all']:
    
    df_lavaan = pd.read_csv(os.path.join(datapath, 'CSV',
                                     'mediation', 'lavaan_wm2_%s.csv'%trials))
    df_lavaan2 = df_lavaan.pivot_table(values='est', index='subj_idx', columns='label').reset_index()
    df_keep = pd.merge(df_lavaan2, rep, on='subj_idx')

    df['x'] = 0
    ylims = [[0.0051, 0.0051, 0.0051, 0.25], [0.15, 0.15, 0.15, 0.15, 0.15, 0.15]]

    for vsidx, varsets in enumerate([['indirect_gamma_stim',  'indirect_gamma_delay']]):
                
        plt.close('all')
        fig, ax = plt.subplots(nrows=1, ncols=len(varsets), figsize=(len(varsets)*1.3, 2))
        
        for gridx, groups in enumerate(['all', 'alternators', 'repeaters']):
            group_markers = ['s', 'o', '^']
            
            # merge these different ones
            df = pd.merge(df_lavaan2, rep, on='subj_idx')
        
            # subselect participants
            if groups == 'alternators':
                df = df[df.repeaters == 0]
                print('removing repeaters')
            elif groups == 'repeaters':
                df = df[df.repeaters == 1]
                print('keeping repeaters')
            elif groups == 'all':
                print('keeping all subjects in')
            
            for vidx, v in enumerate(varsets):
    
                # now the summary
                ttest_against_zero = pg.ttest(df[v] * 10000, 0)
                if ttest_against_zero['p-val'].item() < 0.05:
                    plotvars = {'mec': 'w', 'mfc': cmap[gridx], 'ms': 7}
                else:
                    plotvars = {'mec': cmap[gridx], 'mfc': 'w', 'ms': 5}
    
                yerr = np.array(df[v].mean() - ttest_against_zero['CI95%'].item()[0] / 10000,
                                ttest_against_zero['CI95%'].item()[1] / 10000 - df[v].mean()).T
                ax[vidx].errorbar(y=df[v].mean(), x=gridx, yerr=yerr,
                                  xerr=None, marker=group_markers[gridx], color=cmap[gridx], **plotvars)
                ax[vidx].axhline(0, linestyle='--', color='darkgrey', zorder=-100)
                ax[vidx].set(ylim=[-ylims[vsidx][vidx], ylims[vsidx][vidx]],
                             xlim=[-0.5, 2.2],
                              xlabel='', xticks=[0,1,2],
                              xticklabels=['all', 'alt', 'rep'],
                             ylabel=v)
                
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
                    
                if df[v].mean() > 0:
                    star_y = ttest_against_zero['CI95%'].item()[1] /  10000 * 1.2
                else:
                    star_y = ttest_against_zero['CI95%'].item()[0] / 10000 * 1.4

                ax[vidx].text(gridx, star_y, txt, fontsize='small', ha='center',
                              fontweight='bold', color=cmap[gridx])
                #ax[vidx].tick_params(axis='x', colors='w')
                
                # stats on the groupdiff
                if gridx == 2:
                    ttest2 = pg.ttest(df_keep.loc[df_keep.repeaters == 1, v], 
                                      df_keep.loc[df_keep.repeaters == 0, v], paired=False)
                    pval = ttest2['p-val'].item()
                    txt = "p = {:.4f}".format(pval)
                    if pval < 0.001:
                        txt = "-***-"
                    elif pval < 0.01:
                        txt = "-**-"
                    elif pval < 0.05:
                        txt = "-*-"
                    else:
                        txt = ''

                    # where to put this one?
                    if vidx == 0:
                        y_pos = star_y * 1.4
                    elif vidx == 3:
                        y_pos = star_y * 1.7
                    else:
                        y_pos = star_y * 1.5
        
                    ax[vidx].text(1.5, y_pos, txt, fontsize='small', ha='center', va='top',
                                  fontweight='bold', color='darkgrey')
    
        sns.despine(trim=True)
        fig.tight_layout()
        fig.savefig(os.path.join(datapath, 'figures', 'lavaan_wm2_tr%s_v%s.pdf'%(trials, vsidx)),
                            facecolor='white')
# ====================================================== #
#%% ADD WORKING MEMORY MEDIATION
# ====================================================== #

df_lavaan_corr = pd.read_csv(os.path.join(datapath, 'CSV',
                                 'mediation', 'lavaan_wm2_%s.csv'%'all'))
df_lavaan2_corr = df_lavaan_corr.pivot_table(values='est', index='subj_idx', columns='label').reset_index()

# compute each person's repetition probability
data = pd.read_csv(os.path.join(datapath, 'MEG_HDDM_all_clean', 'allsubjects_megall_4hddm_norm_flip.csv'))
rep = data.groupby(['subj_idx'])['repeat'].mean().reset_index()
rep['repeaters'] = (rep['repeat'] > 0.5)
df_keep = pd.merge(df_lavaan2_corr, rep, on='subj_idx')

group_markers = ['o', '^', 's']
for gridx, groups in enumerate(['alternators', 'repeaters']):
        
    # subselect participants
    if groups == 'repeaters':
        df = df_keep[df_keep.repeaters]
    elif groups == 'alternators':
        df = df_keep[~df_keep.repeaters]
        # else,  do nothing
    
    x = [-0.1, 0.1]
    ylims = [[0.005, 0.005, 0.15]]
    plt.close('all')
    fig, ax = plt.subplots(nrows=1, ncols=3, figsize=(3 * 1.3, 2))
    
    for vsidx, varsets in enumerate([['indirect_gamma_stim', 'indirect_gamma_delay', 'direct']]):
    
        for vidx, v in enumerate(varsets):
    
            # now the summary
            ttest_against_zero = pg.ttest(df[v] * 10000, 0)
            if ttest_against_zero['p-val'].item() < 0.05:
                plotvars = {'mec': 'w', 'mfc': 'k', 'ms': 8}
            else:
                plotvars = {'mec': 'k', 'mfc': 'w', 'ms': 6}

            yerr = np.array(df[v].mean() - ttest_against_zero['CI95%'].item()[0] / 10000,
                            ttest_against_zero['CI95%'].item()[1] / 10000 - df[v].mean()).T
            ax[vidx].errorbar(y=df[v].mean(), x=0, yerr=yerr,
                              xerr=None, marker=group_markers[gridx], color='k', **plotvars)
            ax[vidx].axhline(0, linestyle=':', color='.15', zorder=-100)
            ax[vidx].set(ylim=[-ylims[vsidx][vidx], ylims[vsidx][vidx]],
                         xticks=[],
                         # xlim=[-0.3, 0.3], 
                         #    ylim=[-np.max(np.abs(df[v])) * 1.1, np.max(np.abs(df[v])) * 1.1],
                         xlabel='',  ylabel=v)
            # ax[vidx].set_xticklabels(['correct', 'error'], rotation=-30)
            # [t.set_color(i) for (i, t) in zip(cols, ax[vidx].xaxis.get_ticklabels())]

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
            ax[vidx].text(0, ttest_against_zero['CI95%'].item()[1] / 10000 * 1.1,
                          txt,
                          fontsize='small', ha='center',
                          fontweight='bold')

    sns.despine(trim=True)
    plt.tight_layout()
  #  fig.savefig(os.path.join(datapath, 'Figures', 'lavaan_wm_group%s.pdf'%groups), facecolor='white')
    

# ====================================================== #
#%% ADD WORKING MEMORY MEDIATION - repeaters and alternators together
# ====================================================== #

group_markers = ['o', '^', 's']
df_lavaan_corr = pd.read_csv(os.path.join(datapath, 'CSV',
                                 'mediation', 'lavaan_wm2_%s.csv'%'all'))
df_lavaan2_corr = df_lavaan_corr.pivot_table(values='est', index='subj_idx', columns='label').reset_index()

# compute each person's repetition probability
df_keep = pd.merge(df_lavaan2_corr, rep, on='subj_idx')
# cmap = sns.color_palette('ch:s=.25,rot=-.25', n_colors=2)
cmap1 = sns.color_palette('PuOr', n_colors=7)
cmap = [cmap1[1], cmap1[len(cmap1)-2]]

x = [-0.1, 0.1]
ylims = [[0.005, 0.005, 0.15]]
plt.close('all')
fig, ax = plt.subplots(nrows=1, ncols=3, figsize=(3 * 1.3, 2))
    
for gridx, groups in enumerate(['alternators', 'repeaters']):
    
    # subselect participants
    if groups == 'repeaters':
        df = df_keep[df_keep.repeaters == 1.]
    elif groups == 'alternators':
        df = df_keep[df_keep.repeaters == 0.]
        # else,  do nothing

    for vsidx, varsets in enumerate([['indirect_gamma_stim', 'indirect_gamma_delay', 'direct']]):
        for vidx, v in enumerate(varsets):
    
            # now the summary
            ttest_against_zero = pg.ttest(df[v] * 10000, 0)
            if ttest_against_zero['p-val'].item() < 0.05:
                plotvars = {'mec': 'w', 'mfc': cmap[gridx], 'ms': 8}
            else:
                plotvars = {'mec': cmap[gridx], 'mfc': 'w', 'ms': 6}

            yerr = np.array(df[v].mean() - ttest_against_zero['CI95%'].item()[0] / 10000,
                            ttest_against_zero['CI95%'].item()[1] / 10000 - df[v].mean()).T
            ax[vidx].errorbar(y=df[v].mean(), x=x[gridx], yerr=yerr,
                              xerr=None, marker=group_markers[gridx], color=cmap[gridx], **plotvars)
            ax[vidx].axhline(0, linestyle=':', color='.15', zorder=-100)
            ax[vidx].set(ylim=[-ylims[vsidx][vidx], ylims[vsidx][vidx]],
                         xlim=[-0.3, 0.3], xticks=x,
                         #    ylim=[-np.max(np.abs(df[v])) * 1.1, np.max(np.abs(df[v])) * 1.1],
                         xlabel='',  ylabel=v)
            ax[vidx].set_xticklabels(['alt', 'rep'], rotation=-30)
            # [t.set_color(i) for (i, t) in zip(cols, ax[vidx].xaxis.get_ticklabels())]

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
            ax[vidx].text(x[gridx], ttest_against_zero['CI95%'].item()[1] / 10000 * 1.1,
                          txt,
                          fontsize='small', ha='center',
                          fontweight='bold', color=cmap[gridx])

    sns.despine(trim=True)
    plt.tight_layout()
    fig.savefig(os.path.join(datapath,
                             'figures', 'lavaan_wm_groups.pdf'), facecolor='white')
    
