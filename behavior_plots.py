#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Jan  7 09:38:12 2022

@author: urai
"""

import pandas as pd
import os
import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np
import scipy as sp

from hddmnn_funcs import seaborn_style
seaborn_style()

#%%
mypath = '/Users/urai/Data/projects/0/neurodec/Data/MEG-PL'
df = pd.read_csv(os.path.join(mypath, 'CSV', 'allsubjects_meg.csv'))
df = df[df.subj_idx != 16] # remove one bad subject

# add some history measures
df['prevstim'] = df.stimulus.shift(1)
df['prevresp'] = df.response.shift(1)
df['stimrepeat'] = np.where(df.stimulus == df.prevstim, 1, 0)
df['repeat'] = np.where(df.response == df.prevresp, 1, 0)

# skip trials that are not consecutive
df['wrongtrl'] = np.where(df.trial == df.trial.shift(1) + 1, 1, 0)
df.loc[df.wrongtrl == 0, ['prevstim', 'prevresp', 'stimrepeat', 'repeat']] = np.nan
keep_sj_allsessions = df.subj_idx.unique()
marker_set = ['o', 's', '^'] # in case we use MEG sessions only, there is 0 unclassified sj

df_subj = df.groupby(['subj_idx'])['stimrepeat', 'repeat'].mean().reset_index()
df_subj['repetition'] = df_subj.repeat
df_subj_melt = df_subj.melt(id_vars=['subj_idx', 'repetition'])
df_subj_melt['x'] = np.where(df_subj_melt.variable == 'repeat', 1, 0) + df_subj_melt.repetition

# define groups, exclude P39
df_subj_melt['repeaters'] = 0
df_subj_melt.loc[df_subj_melt.repetition < 0.5, 'repeaters'] = -1
df_subj_melt.loc[df_subj_melt.repetition > 0.5, 'repeaters'] = 1

df_subj_melt_megonly = df_subj_melt.copy()

#%% alternative: 
# mypath = '/Users/urai/Data/projects/0/neurodec/Data/MEG-PL'
# df = pd.read_csv(os.path.join(mypath, 'CSV', 'old', '2ifc_allsessions_hddm.csv'))
# # df = df[df.subj_idx != 16] # remove one bad subject
# df = df[df['subj_idx'].isin(keep_sj_allsessions)]
# df['response'] = df.response.map({1:1, 0:-1})

# # add some history measures
# df['prevstim'] = df.stimulus.shift(1)
# df['prevresp'] = df.response.shift(1)
# df['stimrepeat'] = np.where(df.stimulus == df.prevstim, 1, 0)
# df['repeat'] = np.where(df.response == df.prevresp, 1, 0)

# # skip trials that are not consecutive
# df['wrongtrl'] = np.where(df.trial == df.trial.shift(1) + 1, 1, 0)
# df.loc[df.wrongtrl == 0, ['prevstim', 'prevresp', 'stimrepeat', 'repeat']] = np.nan
# marker_set = ['o', '^'] # alternators and repeaters

# df_subj = df.groupby(['subj_idx'])['stimrepeat', 'repeat'].mean().reset_index()
# df_subj['repetition'] = df_subj.repeat
# df_subj_melt = df_subj.melt(id_vars=['subj_idx', 'repetition'])
# df_subj_melt['x'] = np.where(df_subj_melt.variable == 'repeat', 1, 0) + df_subj_melt.repetition

# # define groups, exclude P39
# df_subj_melt['repeaters'] = 0
# df_subj_melt.loc[df_subj_melt.repetition < 0.5, 'repeaters'] = -1
# df_subj_melt.loc[df_subj_melt.repetition > 0.5, 'repeaters'] = 1

# # =============================== #
# #%% compare all trials vs. MEG trials
# # =============================== #

# df_all = df_subj_melt.loc[df_subj_melt.variable == 'repeat', :]
# df_meg = df_subj_melt_megonly.loc[df_subj_melt_megonly.variable == 'repeat', :]

# pd.crosstab(df_all.repeaters, df_meg.repeaters)

# # repeaters  -1   0   1
# # -1         19   0   6
# #  1          6   1  28
 
# =============================== #
#%% summarize per group
# =============================== #

# sort by repeat, then add hue and a bit of jitter to each x
# figure 1a: repetition in stimulus sequences vs. choice sequences
plt.close('all')
fig, ax = plt.subplots(nrows=1, ncols=1, figsize=(1.5,2))

sns.lineplot(data=df_subj_melt, x='x', y='value', units='subj_idx', hue='repetition',
              estimator=None, legend=False, palette='PuOr', hue_norm=(0.4,0.6),#palette='ch:s=.25,rot=-.25',
              ax=ax, style=df_subj_melt.repeaters, 
              dashes=False, markers=marker_set)
ax.set(yticks=[0.4, 0.5, 0.6], xticks=[0.5, 1.5],
          ylabel='Repetition probability', xlabel='')
ax.set_xticklabels(['stimuli', 'choices'], rotation=-45)
sns.despine(trim=True)
plt.tight_layout()
fig.savefig(os.path.join(mypath, 'Figures', 'behavior_plt0.pdf'))

#%% across-subject correlation
plt.close('all')
fig, ax = plt.subplots(nrows=1, ncols=1, figsize=(2,2))
# correlation between sessions
def corrfunc(x, y, hue, style, ax):
    sns.regplot(x=x, y=y, 
                scatter=False, ci=0, color='darkgrey',
                ax=ax)
    sns.scatterplot(x=x, y=y, 
                hue=hue, style=style,
                legend=False, palette='PuOr', #hue_norm=(0.4,0.6),#palette='ch:s=.25,rot=-.25', 
                markers=marker_set,
                ax=ax)
    r, p = sp.stats.pearsonr(x,y)
    if p < 0.0001:
        ax.text(0.7, 0.1, 'r = %.3f\np < 0.0001'%r, fontsize=6, transform=ax.transAxes)
    else: 
        ax.text(0.7, 0.1, 'r = %.3f\np = %.3f'%(r,p), fontsize=6, transform=ax.transAxes)

df_subj_session = df.groupby(['subj_idx', 'session'])['stimrepeat', 'repeat'].mean().reset_index().dropna()
df_subj_session_melt = df_subj_session.pivot(index='subj_idx', values='repeat',
                                             columns=['session']).reset_index()
df_subj_session_melt.subj_idx.nunique()
corrfunc(df_subj_session_melt[1], df_subj_session_melt[2], 
         df_subj_melt.loc[df_subj_melt.variable == 'repeat', 'repetition'].values, 
         df_subj_melt.loc[df_subj_melt.variable == 'repeat', 'repeaters'].values,
         ax)
ax.set(xlabel='P(repeat), session 1', ylabel='P(repeat), session 2',
          xticks=[0.4, 0.5, 0.6], yticks=[0.4, 0.5, 0.6])
sns.despine(trim=True)
plt.tight_layout()
ax.set_aspect('equal', adjustable='box')
fig.savefig(os.path.join(mypath, 'Figures', 'behavior_plt1.pdf'))

# =============================== #
#%% Fruend kernels
# =============================== #

df_kernels = pd.DataFrame()
for sj in df.subj_idx.unique():
    if os.path.exists(os.path.join(mypath, 'CSV', 'Fruend', 'sj_%02d_kernels.csv'%sj)):
        df_subj_tmp = pd.read_csv(os.path.join(mypath, 'CSV', 'Fruend', 'sj_%02d_kernels.csv'%sj))
        df_subj_tmp.rename(columns={'Unnamed: 0':'Lags'}, inplace=True)
        df_subj_tmp['subj_idx'] = sj
        df_subj_tmp['repetition'] = df_subj_melt.loc[df_subj_melt.subj_idx == sj, 'repetition'].mean()
        
        if os.path.exists(os.path.join(mypath, 'CSV', 'Fruend', 'sj_%02d_perm_wh.csv'%sj)):
            # also get the permutation info
            ll = pd.read_csv(os.path.join(mypath, 'CSV', 'Fruend', 'sj_%02d_loglikelihoods.csv'%sj))
            perm_wh = pd.read_csv(os.path.join(mypath, 'CSV', 'Fruend', 'sj_%02d_perm_wh.csv'%sj))
            df_subj_tmp['pval'] = np.mean(ll['hist'][0] < perm_wh.iloc[:,1].values)
        else:
            df_subj_tmp['pval'] = np.nan

        # append
        df_kernels = df_kernels.append(df_subj_tmp)
        
# group split
df_kernels['repeaters'] = 0
df_kernels.loc[df_kernels.repetition < 0.5, 'repeaters'] = -1
df_kernels.loc[df_kernels.repetition > 0.5, 'repeaters'] = 1

plt.close('all')
fig, ax = plt.subplots(nrows=1, ncols=2, figsize=(4,2), 
                       sharex=True)
# resp kernels on the left
sns.lineplot(data=df_kernels.reset_index(), 
             x='Lags', y='resp_kernel', units='subj_idx', hue='repetition',
             estimator=None, legend=False, palette='PuOr', hue_norm=(0.4,0.6), #palette='ch:s=.25,rot=-.25',
             ax=ax[0], alpha=0.5,
             dashes=False, markers=marker_set)

def ttest(x):
    st = sp.stats.ttest_ind(x, np.zeros(x.shape))
    h = (st[1] < 0.01)
    return h

# which ones are significant?
stats = df_kernels.groupby(['repeaters', 'Lags'])['resp_kernel'].apply(ttest)

# ax[0].set(yticks=[0.4, 0.5, 0.6], xticks=[0.5, 1.5],
#           ylabel='Repetition probability', xlabel='')
# ax[0].set_xticklabels(['stimuli', 'choices'], rotation=-45)

sns.lineplot(data=df_kernels.reset_index(), 
             x='Lags', y='stim_kernel', units='subj_idx', hue='repetition',
             estimator=None, legend=False, palette='PuOr', hue_norm=(0.4,0.6), #palette='ch:s=.25,rot=-.25',
             ax=ax[1], alpha=0.5,
             dashes=False, markers=marker_set)

ax[1].set(xticks=[0,1,2,3,4,5,6], xticklabels=[1,2,3,4,5,6,7])
ax[0].set_ylabel('Previous choice weight')
ax[1].set_ylabel('Previous stimulus weight')

sns.despine(trim=True)
plt.tight_layout()
fig.savefig(os.path.join(mypath, 'Figures', 'behavior_plt2_kernels.pdf'))

#%% # Kernels - average
plt.close('all')
fig, ax = plt.subplots(nrows=1, ncols=2, figsize=(4,2), 
                       sharex=True)
sns.lineplot(data=df_kernels[df_kernels.repeaters != 0].reset_index(), 
             x='Lags', y='resp_kernel', hue='repeaters',
             legend=False, palette='PuOr', hue_norm=(-1.5, 1.5), #palette='ch:s=.25,rot=-.25',
             ax=ax[0], style='repeaters',
             dashes=False, markers=['o', '^'], 
             err_style='bars', zorder=200)
sns.lineplot(data=df_kernels[df_kernels.repeaters != 0].reset_index(), 
             x='Lags', y='stim_kernel', hue='repeaters',
             legend=False, palette='PuOr', hue_norm=(-1.5, 1.5), # palette='ch:s=.25,rot=-.25',
             ax=ax[1], style='repeaters',
             dashes=False, markers=['o', '^'],
             err_style='bars', zorder=100)

ax[0].axhline(0, color='darkgrey', ls=':', zorder=-100)
ax[1].axhline(0, color='darkgrey', ls=':', zorder=-100)
ax[1].set(xticks=[0,1,2,3,4,5,6], xticklabels=[1,2,3,4,5,6,7],
          ylim=[-0.23, 0.3])
ax[0].set(ylim=[-0.23, 0.3])
ax[0].set_ylabel('Choice weight')
ax[1].set_ylabel('Stimulus weight')

sns.despine(trim=True)
plt.tight_layout()
fig.savefig(os.path.join(mypath, 'Figures', 'behavior_plt2_kernels_group.pdf'))

# =============================== #
#%% do the kernels correlate with p(repeat)?
# =============================== 

# define 'true' repeaters/alternators
df_kernels = df_kernels[df_kernels.Lags == 0]
df_kernels['signif'] = df_kernels['pval'] < 0.05
df_kernels['true_repeaters'] = df_kernels['resp_kernel'] > 0
df_kernels.loc[~df_kernels['signif'], 'true_repeaters'] = np.nan

# df_kernels['true_repeaters'].value_counts()
# df_kernels['repeaters'].value_counts()

# df_kernels.groupby(['true_repeaters'])['repeaters'].value_counts()
# df_kernels.groupby(['repeaters'])['resp_kernel'].count()

df_kernels = df_kernels[df_kernels.Lags == 0]
fig, ax = plt.subplots(nrows=1, ncols=2, figsize=(4,2), sharey=True)
corrfunc(df_kernels.resp_kernel, df_kernels.repetition, 
         df_kernels.repetition, df_kernels.repeaters,
         ax[0])
ax[0].set(xlabel='Choice weight',
          ylabel='P(repeat)')
corrfunc(df_kernels.stim_kernel, df_kernels.repetition, 
         df_kernels.repetition, df_kernels.repeaters,
         ax[1])
ax[1].set(xlabel='Stimulus weight')

sns.despine(trim=True)
plt.tight_layout()
fig.savefig(os.path.join(mypath, 'Figures', 'behavior_plt3_fruendcorr.pdf'))

fig, ax = plt.subplots(nrows=1, ncols=1)
sns.scatterplot(data=df_kernels,  ax=ax,
                        x='resp_kernel', y='repetition', marker='.', color='k', zorder=1000)
sns.scatterplot(data=df_kernels,  ax=ax,
                        x='resp_kernel', y='repetition',
                        style='true_repeaters', hue='repeaters', palette='PuOr', hue_norm=(-0.5, 1.5))
ax.axhline(0.5, color='darkgrey')
ax.axvline(0, color='darkgrey')
sns.despine(trim=True)
plt.tight_layout()
fig.savefig(os.path.join(mypath, 'Figures', 'behavior_plt3b_fruendcorr.pdf'))

list(df_kernels.loc[df_kernels['true_repeaters'] == True, 'subj_idx'])
list(df_kernels.loc[df_kernels['true_repeaters'] == False, 'subj_idx'])

# =============================== #
#%% strategy space
# =============================== #

fig, ax = plt.subplots(nrows=1, ncols=1, figsize=(2,2))
sns.scatterplot(x=df_kernels.resp_kernel, y=df_kernels.stim_kernel, 
            hue=df_kernels.repetition, style=df_kernels.repeaters,
            legend=False, palette='PuOr', hue_norm=(0.4,0.6),#palette='ch:s=.25,rot=-.25', 
            markers=marker_set,
            ax=ax)
ax.set(xlabel='Choice weight, lag 1',
       ylabel='Stimulus weight, lag 1',
       xlim=[-0.75, 0.75], ylim=[-0.75, 0.75], 
       xticks=[-0.5, 0, 0.5], yticks=[-0.5, 0, 0.5])
ax.plot([0, 1], [0, 1], color='darkgrey', ls=':', transform=ax.transAxes)
ax.plot([1, 0], [0,1], color='darkgrey', ls=':', transform=ax.transAxes)

kwargs = {'ha':'center', 'va':'center', 'fontsize':6, 'fontstyle':'oblique',
          'transform':ax.transAxes}
ax.text(0.5, 0.85, 'win-stay\nlose-switch', **kwargs)
ax.text(0.5, 0.1, 'win-switch\nlose-stay', **kwargs)
ax.text(0.85, 0.57, 'stay', **kwargs)
ax.text(0.15, 0.56, 'switch', **kwargs)
plt.tight_layout()
ax.set_aspect('equal', adjustable='box')
fig.savefig(os.path.join(mypath, 'Figures', 'behavior_plt4_strategy.pdf'))

# =============================== #
#%% define true repeaters/alternators 
# based on P(repeat across blocks)
# =============================== #

#import pingouin as pg
from permute.core import one_sample

def repetition_across_blocks(df):
    df_bl = df.groupby(['session', 'block'])[['repeat']].mean().reset_index()
    
    # use pingouin for ttest
    #t_stat = pg.ttest(df_bl['repeat'], 0.5)
    #return t_stat[['T', 'p-val']]

    # use scipy for ttest
    t_stat = sp.stats.ttest_ind(df_bl['repeat'], 0.5*np.ones(df_bl['repeat'].shape))
    return pd.DataFrame({'p-val':t_stat[1], 'T':t_stat[0]}, index=[0])

    # use permutation test
    # (p2, diff_means) = one_sample(df_bl['repeat'] - 0.5, stat='mean', 
    #                                alternative='two-sided')
    # return pd.DataFrame({'p-val':p2, 'T':diff_means}, index=[0])
    #return t_stat[0:2]


df_subj_bl = df.groupby(['subj_idx']).apply(repetition_across_blocks).reset_index()
df_subj_bl

df_new = pd.merge(df_kernels[['subj_idx', 'repetition', 'repeaters', 'resp_kernel']], 
                             df_subj_bl[['subj_idx', 'T', 'p-val']], on='subj_idx')

df_new['signif'] = df_new['p-val'] < 0.05
df_new['true_repeaters'] = df_new['repetition'] > 0.5
df_new.loc[~df_new['signif'], 'true_repeaters'] = np.nan

fig, ax = plt.subplots(nrows=1, ncols=1)
sns.scatterplot(data=df_new,  ax=ax,
                        y='repetition', x='T', marker='.', color='k', zorder=1000)
sns.scatterplot(data=df_new,  ax=ax,
                        y='repetition', x='T',
                        style='true_repeaters', hue='repeaters', palette='PuOr', hue_norm=(-0.5, 1.5))
ax.axhline(0.5, color='darkgrey')
ax.axvline(0, color='darkgrey')
sns.despine(trim=True)
plt.tight_layout()
fig.savefig(os.path.join(mypath, 'Figures', 'repetition_ttest_perblock.pdf'))

print(list(df_new.loc[df_new['true_repeaters'] == True, 'subj_idx'])) # 10 true repeaters
print(list(df_new.loc[df_new['true_repeaters'] == False, 'subj_idx'])) # 12 true alternators
print(df_new['true_repeaters'].value_counts())

#%% and make another graph to fill up Figure 1
plt.close('all')
fig, ax = plt.subplots(nrows=1, ncols=1, figsize=[1.5, 2])
df_new['x'] = df_new.repeaters + df_new.repetition + 0.3*np.random.normal(size=df_new.repetition.shape)
df_new.loc[df_new.repetition == 0.5, 'x'] = 0.5
df_new.signif = 1 * df_new.signif

sns.scatterplot(data=df_new, ax=ax,
                        y='repetition', x='x', size='signif',
                        style='repeaters', hue='repetition', 
                        palette='PuOr', hue_norm=(0.4, 0.6),
                        markers=marker_set,
                        sizes={0:10, 1:20},
                        legend=False)
ax.axhline(0.5, color='.15', zorder=-100)
ax.set(xlim=[-1.5, 2.5], ylabel='P(repeat)', xlabel='',
       yticks=[0.4, 0.5, 0.6],
       xticks=[-0.5, 1.5], xticklabels=['alternators', 'repeaters'])

[t.set_color(i) for (i,t) in zip(['#f1a340','#998ec3'], ax.xaxis.get_ticklabels())]
plt.xticks(rotation=-45, ha='left')
sns.despine(trim=True)
plt.tight_layout()
fig.savefig(os.path.join(mypath, 'Figures', 'behavior_plt5_groups.pdf'))


#%% extra: RT distributions, only trials for HDDMnn
plt.close('all')
fig, ax = plt.subplots(nrows=1, ncols=1, figsize=[3, 2])
data = pd.read_csv(os.path.join(mypath, 'CSV', 'data_meg_hddmnn.csv'))
sns.histplot(data.rt, ax=ax)
ax.set(xlabel='Response time (s)')
sns.despine(trim=True)
plt.tight_layout()
fig.savefig(os.path.join(mypath, 'Figures', 'behavior_rt.pdf'))
