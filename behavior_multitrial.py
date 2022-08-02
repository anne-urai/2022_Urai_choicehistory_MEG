#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Jan  7 09:38:12 2022

@author: urai
"""

#%%

import pandas as pd
import os
import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np
import scipy as sp
from scipy import stats
import pingouin as pg

from hddmnn_funcs import seaborn_style, corrplot #, corrfunc
seaborn_style()

#%%
mypath = '/Users/urai/Data/projects/0/neurodec/Data/MEG-PL'
# df = pd.read_csv(os.path.join(mypath, 'CSV', 'allsubjects_meg.csv'))
df = pd.read_csv(os.path.join(mypath, 'CSV', 'allsubjects_meg_complete.csv'))

#%% ======================================
# can you plot the IPS effects (and their individual differences) also as function 
# of choice streaks, rather than of lag? Like the behavior in fig. 1ccan you plot the 
# IPS effects (and their individual differences) also as function of choice streaks, 
# rather than of lag? Like the behavior in fig. 1c

# dfmeg = pd.read_csv(os.path.join(mypath, 'CSV', 'allsubjects_megall_4hddm_norm_flip.csv'))

# # merge
# df = pd.merge(df, dfmeg[['idx', 'subj_idx', 'session', 'block', 'trial', 
#                            'handgroup',
#                            'stimulus', 'hand', 'response', 'rt', 
#                            'gamma_ips23_stimwin', 'gamma_ips23_refwin',
#                            'gamma_ips23_stimwin_resid',
#                            'beta_3motor_lat_refwin',
#                            'alpha_ips01_stimwin_resid']], 
#                 on=['idx', 'subj_idx', 'session', 'block', 'trial', 
#                                            'stimulus', 'hand', 'response', 'rt'],
#                 how="left")

# #%% quick check: are these two even correlated?
# corr_res = []
# for sj, tmpdat in df.groupby(['subj_idx']):
#     r = pg.corr(tmpdat['gamma_ips23_stimwin'], tmpdat['beta_3motor_lat_refwin'], method='pearson')
#     # r, p = sp.stats.spearmanr(tmpdat['gamma_ips23_stimwin'], tmpdat['beta_3motor_lat_refwin'], 
#     #                           nan_policy='omit')
    
#     corr_res.append({'subj_idx':sj,
#                       'r':r['r'][0],
#                       'p':r['p-val'][0]})

# corr_res = pd.DataFrame(corr_res)
# g = sns.histplot(data=corr_res, x='r')
# g.set_xlabel('correlation between IPS2/3 gamma and motor beta')
# t2 = sp.stats.ttest_1samp(corr_res.r.values, 0)
# g.set_title('average r = %.3f, t = %.3f, p = %.4f\nsignificant in %02d/%02d subjects'%(
#     corr_res.r.mean(),
#     t2[0], t2[1], (corr_res['p'] < 0.05).sum(), (corr_res['p']).count()))
# plt.savefig(os.path.join(mypath, 'Figures', 'correlation_between_signals.pdf'))

#%%
def find_template_match(string, trialnum, template):
    
    # now find the sequences
    matches_start = [index for index in range(len(string)) if 
               string.startswith(template, index)]
    
    # find the index of the choice *following* the sequence
    matches_end = [i + len(template) for i in matches_start]
    
    # remove sequences where the trial numbers are not consecutive
    consec_trials = [mend for mstart, mend in zip(matches_start, matches_end)
                      if trialnum[mstart+1:mend+1].all()]
    
    # remove any idx that are beyond the length of the df
    consec_trials = [i for i in consec_trials if i < len(string)]
    
    return consec_trials

# dprime and criterion
def sdt(stim, resp):
    
    # http://gureckislab.org/courses/fall19/labincp/labs/lab2sdt_pt1.html
    hit = (resp[stim > 0] > 0).mean()
    fa = (resp[stim <= 0] > 0).mean()
    
    # these must be within range
    # correct for 100% or 0% values, will lead to Inf norminv output
    if hit > 0.999:
        hit = 0.999
    if hit < 0.001:
        hit = .001
    if fa < 0.001:
        fa = 0.001
    if fa > 0.999:
        fa = 0.999

    # compute with norminv
    dprime = stats.norm.ppf(hit) - stats.norm.ppf(fa)
    crit = -0.5 * (stats.norm.ppf(hit) + stats.norm.ppf(fa))
    
    return dprime, crit

# =============================== #
#%% sequences, Akaishi fig. 1E
# =============================== #

def repeating_bias(df, nr_reps=3, neural=[],
                   correct_only_all=False, 
                   last_trial='any', first_trial='any'):
    
    results = []
    for nrep in range(0, nr_reps+1): # loop over different repetitions
        for match_final in [0,1]: # match the final one or not
        
            # do this for different stimulus identities; merge
            for idx, resp_id in enumerate(zip(['A', 'B'], ['B', 'A'])): 
            
                # construct the template sequence
                if match_final:
                    template = str(resp_id[0])*nrep + str(resp_id[0])
                else:
                    # if we check for alternation tendencies
                    # alt_temp = nrep*(str(resp_id[1]) + str(resp_id[0])) + str(resp_id[1])
                    # template = alt_temp[-(nrep+1)::]
                    # if we do the same analysis as Akaishi
                    template = str(resp_id[0])*nrep + str(resp_id[1])
                print(template)
              
                # convert the sequence of choices into a long string
                choices_dict = {1.: 'A', 0.: 'B', np.nan: '0'}
                choices_str = df.response.map(choices_dict).astype(str).str.cat()
                assert(len(choices_str) == len(df))
    
                # also make a string for trial numbers - are they sequential?
                trialnum = (df.trial == df.trial.shift(1) + 1)
                assert(len(trialnum) == len(df))
                
                # find indices of all trials *after* this sequence
                indices = find_template_match(choices_str, trialnum, template)

                # subselect those where *all* the previous responses were correct
                correct_str = df.correct.map({1.: '1', 0: '0', 
                                            np.nan: '2'}).astype(str).str.cat()
                assert(len(correct_str) == len(df))
                if correct_only_all:
                    indices_correctstreak = find_template_match(correct_str, trialnum,
                                                                str('1')*(nrep+1))
                    indices = [i for i in indices if i in indices_correctstreak]
                
                # sanity checks:
                # is the last item of the sequence as we intended?
                if len(indices) > 0:
                    assert(list(set([choices_str[i-1] for i in indices])) == [template[-1]])
            
                # ====== is the first or last trial correct or error?
                if last_trial == 'any':
                    # do nothing
                    print('')
                elif last_trial == 'error':
                    indices = [i for i in indices if correct_str[i-1] == '0']
                    if len(indices) > 0:
                        assert(list(set([correct_str[i-1] for i in indices])) == ['0'])
                elif last_trial == 'correct':
                    indices = [i for i in indices if correct_str[i-1] == '1']
                    if len(indices) > 0:
                        assert(list(set([correct_str[i-1] for i in indices])) == ['1'])
                else:
                    print('Warning: unknown input argument')

                # ====== is the first or last trial correct or error?
                if first_trial == 'any':
                    # do nothing
                    print('keeping all trials')
                elif first_trial == 'error':
                    indices = [i for i in indices if correct_str[i-len(template)] == '0']
                    if len(indices) > 0:
                        assert(list(set([correct_str[i-len(template)] for i in indices])) == ['0'])
                elif first_trial == 'correct':
                    indices = [i for i in indices if correct_str[i-len(template)] == '1']
                    if len(indices) > 0:
                        assert(list(set([correct_str[i-len(template)] for i in indices])) == ['1'])
                else:
                    print('Warning: unknown input argument')
                    
                # unflipped
                stimuli = 1 * (df.iloc[indices]['stimulus'] == 1.)
                responses = 1 * (df.iloc[indices]['response'] == 1.)

                # compute the response criterion
                if len(indices) > 2: # minimum nr of trials
                    dprime, crit    = sdt(stimuli, responses)
                    #dprime_flip, crit_flip    = sdt(stimuli_flip, responses_flip) # also flipped
                    
                    res_dict = {'criterion': -crit,
                                    'presp': responses.mean() - 0.5,
                                    'pstim': stimuli.mean() - 0.5,
                                    'dprime': dprime,
                                    'nr_trials': len(indices),
                                    'nr_reps': nrep,
                                    'match_final': match_final,
                                    'correct_only_all': correct_only_all,
                                    'which_resp': resp_id,
                                    'template': template,
                                    'template2': template.replace('A','2').replace('B','1'),
                                    'last_item':template[-1].replace('A','2').replace('B','1')}
                
                    # add the average neural response
                    for n in neural:
                        res_dict.update({n:np.mean(df.iloc[indices][n])}) # dont flip

                    # collect results into list of dicts
                    results.append(res_dict)
                    
    return pd.DataFrame(results)
        
#%% ========================== %%
# RUN
# ========================== %%

df_sequences_saveall = pd.DataFrame()
for correct_only_all in [False]:
    for last_trial in ['any', 'error', 'correct']:
        for first_trial in ['any', 'error', 'correct']:
            
            if correct_only_all == True and ((last_trial != 'any') or (first_trial != 'any')):
                continue
 
            # ========================== %%
            # run the code
            # ========================== %%
            
            neural_var = ['gamma_ips23_stimwin', 'beta_3motor_lat_refwin', 
                          'alpha_ips01_stimwin_resid',
                          'gamma_ips23_refwin', 'gamma_ips23_stimwin_resid']
            df_sequences = df.groupby(['group', 'repetition',
                                        'subj_idx']).apply(repeating_bias, neural=neural_var,
                                                          correct_only_all=correct_only_all,
                                                          last_trial=last_trial,
                                                          first_trial=first_trial,
                                                          nr_reps=4).reset_index()
                                                    
            #%% ========================== %%
            # do the flipping
            # ========================== %%
            
            df_sequences_toflip = df_sequences.copy()
            # flip the values around if the last choice is 'B' (i.e. 'weaker')
            df_sequences_toflip.loc[(df_sequences_toflip.last_item == '1'),
                                    ['criterion', 'gamma_ips23_stimwin', 'beta_3motor_lat_refwin',
                                                           'gamma_ips23_refwin', 'alpha_ips01_stimwin_resid',
                                                           'gamma_ips23_stimwin_resid',
                                                           'pstim', 'presp']] *= -1
            
            df_sequences_avg = df_sequences_toflip.groupby(['group', 'repetition',
                                                     'subj_idx',
                                                     'match_final',
                                                     'nr_reps']).agg({'criterion':'mean',
                                                                      'gamma_ips23_stimwin':'mean',
                                                                      'beta_3motor_lat_refwin':'mean',
                                                                      'gamma_ips23_refwin':'mean',
                                                                      'gamma_ips23_stimwin_resid':'mean',
                                                                      'alpha_ips01_stimwin_resid':'mean',
                                                                      'pstim':'mean',
                                                                      'presp':'mean',
                                                                      'template':'unique',
                                                                      'template2':'unique'}).reset_index()
            
            # sequences_template = df_sequences_toflip.groupby(['last_item','match_final', 
            #                                          'nr_reps'])['template'].unique().reset_index()
            df_sequences_avg.dropna(axis=0, inplace=True) # remove NaNs
            
            # save into huge dataframe for easier later plotting
            df_sequences_avg['correct_only_all'] = correct_only_all
            df_sequences_avg['last_trial'] = last_trial
            df_sequences_avg['first_trial'] = first_trial
            df_sequences_saveall = pd.concat([df_sequences_saveall, df_sequences_avg], sort=False)

            #%% ========================== %%
            # ONE HUGE PLOT
            # ========================== %%
            
            df_sequences['hue'] = (df_sequences.which_resp != ('A', 'B')) - 2 * (df_sequences.last_item == '1') 
            plot_vars = ['pstim', 'presp', 'criterion', 
                         'gamma_ips23_stimwin', 'beta_3motor_lat_refwin', 
                         'gamma_ips23_refwin', 'gamma_ips23_stimwin_resid']
            
            plt.close('all')
            fig, ax = plt.subplots(nrows=len(plot_vars), ncols=5, 
                                        sharex=False, sharey=False, figsize=(13,14))
            
            for vidx, v in enumerate(plot_vars):
                for gridx, whichgroup in enumerate([-1, 1]):
                    
                    hline = 0
                        
                    ### 1. not flipped
                    kwargs = {'x':'nr_reps',
                          'hue':'hue', 'hue_order':[1, 0, -2, -1], # make sure the colors make sense
                          'palette':'Paired',
                          'err_style':'bars', 
                          'zorder':200, 'legend':False}
                    
                    # first the lines only
                    sns.lineplot(data=df_sequences.loc[df_sequences.group == whichgroup],
                                 y = v,
                                 ax=ax[vidx, gridx], markers=False, alpha=0.3, ci=95,
                                 **kwargs)
                    # now overlay the templates as markers
                    mrk = ['$' + s + '$' for s in df_sequences.template2.unique()]
                    sns.lineplot(data=df_sequences.loc[df_sequences.group == whichgroup],
                              ax=ax[vidx, gridx], 
                              y=v, # add numbers
                              style='template2', style_order=df_sequences.template2.unique(),
                              markers=mrk, mec=None, mfc='auto', ms=10, ci=False,
                              **kwargs)
                    
                    ax[vidx, gridx].axhline(hline, color='darkgrey', ls=':', zorder=-100)
                    ax[vidx, gridx].set(xlabel='', title='')
                    plt.xticks(range(0, 5), labels=[''] * 5)
                    
                    # ### 2. flipped
                    # sns.lineplot(data=df_sequences.loc[df_sequences.repeaters == whichgroup],
                    #              y = v + '_flip',
                    #           ax=ax[vidx, gridx + 2], marker='o', ci=95,
                    #           **kwargs)
                
                    # # layout
                    # ax[vidx, gridx + 2].axhline(hline, color='darkgrey', ls=':', zorder=-100)
                    # ax[vidx, gridx + 2].set(xlabel='', title='')
                    # plt.xticks(range(0, 4), labels=[''] * 4)
             
                    ### 3. flipped, black-red
                    kwargs = {'x':'nr_reps', 'y':v,
                              'hue':'match_final', 'hue_order':[0, 1, 0.5],
                              'palette':['black', 'firebrick', 'darkgrey'],
                              'err_style':'bars', 'ci':95,
                              'zorder':200, 'legend':False}
                    
                    # marker_style.update(markeredgecolor="none", markersize=15)
                    sns.lineplot(data=df_sequences_avg.loc[df_sequences_avg.group == whichgroup],
                                  marker='o', ax=ax[vidx, gridx + 2], 
                                  **kwargs)
                    
                    # do an ANOVA
                    anov = pg.rm_anova(data = df_sequences_avg.loc[(df_sequences_avg.group == whichgroup) 
                                                                   & (df_sequences_avg.match_final != 0.5)], 
                                    dv = v,
                                    within = ['nr_reps', 'match_final'],
                                    subject='subj_idx',
                                    detailed=False)
                    # print the stats in the title
                    stats_str = 'nr_reps F(%02d, %02d) = %.2f, p = %.3f\n'%(anov['ddof1'][0], 
                                                                            anov['ddof2'][0], 
                                                                            anov['F'][0], 
                                                                            anov['p-GG-corr'][0]) + \
                                'match_final F(%02d, %02d) = %.2f,p = %.3f\n'%(anov['ddof1'][1], 
                                                                       anov['ddof2'][1], 
                                                                       anov['F'][1], 
                                                                       anov['p-GG-corr'][1]) +  \
                                'interaction F(%02d, %02d) = %.2f, p = %.3f'%(anov['ddof1'][2], 
                                                                 anov['ddof2'][2], 
                                                                 anov['F'][2], 
                                                                 anov['p-GG-corr'][2])
                    ax[vidx, gridx + 2].set_title(stats_str, fontsize=6)
       
                    # horizontal line
                    ax[vidx, gridx + 2].axhline(hline, color='darkgrey', ls=':', zorder=-100)
                    ax[vidx, gridx + 2].set(xlabel='')
                    #plt.xticks(range(0, 5), labels=[''] * 5)
                        
                    # markings
                    if vidx == 0:
                        if gridx == 0:
                            ax[vidx, gridx].set_title('Alternators')
                            ax[vidx, gridx + 2].set_title('Alternators')
            
                        elif gridx == 1:
                            ax[vidx, gridx].set_title('Repeaters')
                            ax[vidx, gridx + 2].set_title('Repeaters')
            
                    if gridx == 1:
                        ax[vidx, gridx].set_ylabel('')
                        ax[vidx, gridx + 2].set_ylabel('')
                        
                ### 4. similarity with behavior
                if v == 'criterion':
                    ax[vidx, 4].set_axis_off()
                else:
                    # compute the correlation per subject
                    for gr, x in df_sequences_avg.groupby(['group', 'repetition', 
                                                             'subj_idx']):
                        print(x[['criterion', v]])
                    
                    similarity_index = df_sequences_avg.groupby(['group', 'repetition', 
                                                             'subj_idx']).apply(lambda x: 
                                                                                stats.pearsonr(x['criterion'], 
                                                                                               x[v])).reset_index()
                        
                    # nr_datap = df_sequences_group.groupby(['subj_idx'])['criterion'].count() # quick check
                    # unfold from tuple
                    similarity_index['r'] = [i[0] for i in similarity_index[0]]
                    similarity_index['pval'] = [i[1] for i in similarity_index[0]]
                    similarity_index['h'] = 1 * (similarity_index.pval < 0.05)
                    
                    ## ========== ## plot
                    # marker_style.update(markeredgecolor="none", markersize=15)
                    sns.lineplot(data=similarity_index,
                                 x='repetition', y='r', hue='repetition', palette='PuOr',
                                 hue_norm=(0.4,0.6),
                                 style='h', markers=['o', 's'], linestyle='',
                                 ax=ax[vidx, 4], dashes=False, legend=False)
                    ax[vidx, 4].set(ylabel='Similarity index', xlabel='')
                    
                    # # test the correlation coefficients across the group
                    ttest_random = sp.stats.ttest_1samp(similarity_index['r'], 0)
                    ttest_rep = sp.stats.ttest_1samp(similarity_index[similarity_index.group == 1]['r'], 0)
                    ttest_alt = sp.stats.ttest_1samp(similarity_index[similarity_index.group == -1]['r'], 0)

                    # now also test this as a fixed effect
                    group_fixed = df_sequences_avg.groupby(['nr_reps','match_final']).mean()
                    rep_fixed = df_sequences_avg[df_sequences_avg.group == 1].groupby(['nr_reps','match_final']).mean()
                    alt_fixed = df_sequences_avg[df_sequences_avg.group == -1].groupby(['nr_reps','match_final']).mean()
                    similarity_index_fixed = stats.pearsonr(group_fixed['criterion'],group_fixed[v])
                    similarity_index_fixed_rep = stats.pearsonr(rep_fixed['criterion'], rep_fixed[v])
                    similarity_index_fixed_alt = stats.pearsonr(alt_fixed['criterion'], alt_fixed[v])
                                
                    # print the stats in the title
                    stats_str = 'random t = %.2f, p = %.3f\n'%(ttest_random[0], ttest_random[1]) + \
                                'random alt p = %.3f, random rep p = %.3f\n'%(ttest_alt[1], ttest_rep[1]) + \
                                'fixed p = %.3f, alt r = %.2f, p = %.3f, rep r = %.2f, p = %.3f'%( similarity_index_fixed[1],
                                                                                                           similarity_index_fixed_alt[0],
                                                                                                           similarity_index_fixed_alt[1],
                                                                                                           similarity_index_fixed_rep[0],
                                                                                                           similarity_index_fixed_rep[1])
                    
                    ax[vidx, 4].set_title(stats_str, fontsize=6)
                    ax[vidx, 4].set_ylim([-1,1])
                    
                    if vidx == len(plot_vars)-1:
                        ax[vidx, 4].set_xlabel('P(repeat)')
                    
            # save the whole thing
            # sns.despine(trim=True)
            plt.tight_layout()
            if correct_only_all:
                fig.suptitle('Last trial X = %s; all trials in sequence correct'%last_trial)
                fig.savefig(os.path.join(mypath, 'Figures', 'sequences_overview_allcorrect.pdf'))
            else:
                fig.suptitle('Last trial X = %s'%last_trial)
                fig.savefig(os.path.join(mypath, 'Figures', 'sequences_overview_last%s_first%s.pdf'%(last_trial, first_trial)))
            print('figure saved')
        
df_sequences_saveall.to_csv(os.path.join(mypath, 'CSV', 'sequences_akaishi.csv'))

# ========================= #
#%% SAVE DATA FOR JASP
# wide format: run a 3-way ANOVA with 2 RM (within-subject) and 1 across-subject factor
# ========================= #

mypath = '/Users/urai/Data/projects/0/neurodec/Data/MEG-PL'
df_sequences_saveall = pd.read_csv(os.path.join(mypath, 'CSV', 'sequences_akaishi.csv'))

for vv in ['criterion', 'gamma_ips23_stimwin']:
    df_jasp = pd.pivot_table(df_sequences_saveall, index=['subj_idx', 'group'],
                             values=vv, columns=['nr_reps', 'match_final'])
    df_jasp = pd.DataFrame(df_jasp.to_records())
    df_jasp = df_jasp[df_jasp.group != 0]
    
    print(df_jasp)
    df_jasp.to_csv(os.path.join(mypath, 'CSV', 'sequences_akaishi_jasp_%s.csv'%vv))

# ========================= #
#%% plot a few specific things!
# ========================= #

mypath = '/Users/urai/Data/projects/0/neurodec/Data/MEG-PL'
df_sequences_saveall = pd.read_csv(os.path.join(mypath, 'CSV', 'sequences_akaishi.csv'))
# dodge to better display
df_sequences_saveall.loc[(df_sequences_saveall.match_final==False) & \
                         (df_sequences_saveall.nr_reps > 0), 'nr_reps'] -= 0.05 # dodge
df_sequences_saveall.loc[(df_sequences_saveall.match_final==True) & \
                         (df_sequences_saveall.nr_reps > 0), 'nr_reps'] += 0.05 # dodge

for plot_var in ['criterion', 'gamma_ips23_stimwin', 
                 'beta_3motor_lat_refwin', 'alpha_ips01_stimwin_resid']:
    kwargs = {'x':'nr_reps', 'y':plot_var,
              'hue':'match_final', 'hue_order':[0, 1, 0.5],
              'palette':['black', 'firebrick', 'darkgrey'],
              'err_style':'bars', 'ci':95,
              'zorder':200, 'legend':False}
    kwargs2 = {'x':'nr_reps', 'y':plot_var,
              'color':'dimgrey', 'ms':6,
              'err_style':'bars', 'ci':95,
              'zorder':300, 'legend':False}
    markers = ['o', '^']
    fig, ax = plt.subplots(nrows=1, ncols=2, figsize=(3.8,2), sharex=True, sharey=True)
    
    for gridx, gr in enumerate([-1, 1]):
        sns.lineplot(data=df_sequences_saveall.loc[(df_sequences_saveall.group == gr) & \
                                               (df_sequences_saveall.first_trial == 'any') & \
                                                   (df_sequences_saveall.last_trial == 'any') & \
                                                       (df_sequences_saveall.correct_only_all == False)],
                  marker=markers[gridx], ax=ax[gridx], **kwargs)
        # overlay the first datapoint in grey
        data_subset_2nd = df_sequences_saveall.loc[(df_sequences_saveall.group == gr) & \
                                                   (df_sequences_saveall.nr_reps == 0) & \
                                               (df_sequences_saveall.first_trial == 'any') & \
                                                   (df_sequences_saveall.last_trial == 'any') & \
                                                       (df_sequences_saveall.correct_only_all == False)]
        sns.lineplot(data=data_subset_2nd, marker=markers[gridx], ax=ax[gridx], **kwargs2)
            
        # do an ANOVA
        data_subset_anov = df_sequences_saveall.loc[(df_sequences_saveall.group == gr) & \
                                                       (df_sequences_saveall.nr_reps > 0) & \
                                                   (df_sequences_saveall.first_trial == 'any') & \
                                                       (df_sequences_saveall.last_trial == 'any') & \
                                                           (df_sequences_saveall.correct_only_all == False)]
        anov = pg.rm_anova(data = data_subset_anov,
                        dv = plot_var,
                        within = ['nr_reps', 'match_final'],
                        subject='subj_idx',
                        detailed=False)
        #pg.print_table(anov)
        # print the stats in the title
        new_pvals = ['p = %.3f'%p if p > 0.001 else 'p < 0.001' for p in anov['p-GG-corr'] ]
        new_pvals = ['p = %.3f'%p if p > 0.001 else 'p = ' + 
                     np.format_float_scientific(p, precision = 2, exp_digits=3) for p in anov['p-GG-corr'] ]

        stats_str = 'Sequence length: %s\nSequence end: %s\nInteraction: %s'%tuple(new_pvals)    
        ax[gridx].axhline(0, color='darkgrey', ls=':', zorder=-100)
        ax[gridx].set(xlabel='')
        ax[gridx].set_title(stats_str, fontsize='xx-small', y=0.77) #, #pad=-30)
    
    plt.xticks(range(0, 5), labels=['1', '2', '3', '4', '5'])              
    sns.despine(trim=True)
    #fig.supxlabel('Choice history')
    if plot_var == 'criterion':
        ax[0].set_ylabel(r'Repeating bias ($\Delta$c)')
        ax[0].set_ylim([-0.4, 0.4])
    elif plot_var == 'gamma_ips23_stimwin':
        ax[0].set_ylabel('Previous choice effect\nin IPS2/3 gamma-band')
    elif plot_var == 'alpha_ips01_stimwin_resid':
        ax[0].set_ylabel('Previous choice effect\nin IPS0/1 alpha-band')

    elif plot_var == 'beta_3motor_lat_refwin':
        ax[0].set_ylabel('Previous choice effect\nin Motor beta lateralization')


    ax[0].set_xlabel('Sequence length')
    ax[1].set_xlabel('Sequence length')
    seaborn_style()
    plt.tight_layout()
    fig.savefig(os.path.join(mypath, 'Figures', 'seq_any_%s.pdf'%plot_var), transparent=False)
    
    df_sequences_saveall.groupby(['group'])[['subj_idx']].nunique()

#%% repeating/alternating bias, a la Hermoso-Mendizabel figure 2E
kwargs = {'x':'nr_reps', 'y':'criterion',
          'hue':'last_trial', 'hue_order':['correct', 'error'],
          'err_style':'bars', 'ci':95,
          'zorder':200, 'legend':False}
markers = ['o', '^']
fig, ax = plt.subplots(nrows=1, ncols=4, figsize=(5.8,2), sharex=True, sharey=True)
for gridx, gr in enumerate([-1, 1]):
    
    # first the top plot; figure 2E, left (repeating sequences with first or last error)
    data_subset = df_sequences_saveall.loc[(df_sequences_saveall.group == gr) & \
                                           (df_sequences_saveall.match_final == 1) & \
                                           (df_sequences_saveall.last_trial != 'any') & \
                                           (df_sequences_saveall.first_trial == 'any') & \
                                           (df_sequences_saveall.correct_only_all == False)]
    print(data_subset.groupby(['nr_reps'])['template'].unique())
    sns.lineplot(data=data_subset, marker=markers[gridx], ax=ax[0+gridx*2], 
                 palette=['purple', 'black'], **kwargs)
    
    # then the bottom plot; figure 2E, right (alternating sequences with first or last error)
    data_subset = df_sequences_saveall.loc[(df_sequences_saveall.group == gr) & \
                                           (df_sequences_saveall.match_final == 0) & \
                                           (df_sequences_saveall.last_trial != 'any') & \
                                           (df_sequences_saveall.first_trial == 'any') & \
                                           (df_sequences_saveall.correct_only_all == False)]
    print(data_subset.groupby(['nr_reps'])['template'].unique())
    sns.lineplot(data=data_subset, marker=markers[gridx], ax=ax[1+gridx*2], 
                 palette=['chocolate', 'black'], **kwargs)
    
    ax[0+gridx*2].axhline(0, color='darkgrey', ls=':', zorder=-100)
    ax[1+gridx*2].axhline(0, color='darkgrey', ls=':', zorder=-100)
    ax[0+gridx*2].set(xlabel='', ylim=[-0.75, 0.75])
    ax[0+gridx*2].set_ylabel(r'Repeating bias ($\Delta$c)')
    ax[1+gridx*2].set_ylabel(r'Repeating bias ($\Delta$c)')
    ax[1+gridx*2].set_xlabel('')

fig.supxlabel('Sequence length', y=0.08, fontsize='medium')
plt.xticks(range(0, 5), labels=['1', '2', '3', '4', '5'])              
sns.despine(trim=True)
#fig.supxlabel('Choice history')
seaborn_style()
plt.tight_layout()
fig.savefig(os.path.join(mypath, 'Figures', 'seq_errors.pdf'))

# ========================= #
#%% is there a between subject correlation?
# ========================= #

mypath = '/Users/urai/Data/projects/0/neurodec/Data/MEG-PL'
df_seq = pd.read_csv(os.path.join(mypath, 'CSV', 'sequences_akaishi.csv'))

# grab the mail data
data_subset = df_seq[['subj_idx', 'group', 'repetition',
                           'nr_reps', 'match_final',
                           'first_trial', 'last_trial',
                           'criterion', 'gamma_ips23_stimwin']].loc[(df_seq.nr_reps > 0) & \
                              (df_seq.first_trial == 'any') & (df_seq.last_trial == 'any') & 
                              (df_seq.correct_only_all == False)]
data_subset.groupby(['subj_idx'])['gamma_ips23_stimwin'].nunique()
                                                             
similarity_index = data_subset.groupby(['group', 'repetition', 
                                         'subj_idx']).apply(lambda x: 
                                                            stats.pearsonr(x['criterion'], 
                                                                           x['gamma_ips23_stimwin'])).reset_index()
                                                            
similarity_index['r'] = [i[0] for i in similarity_index[0]]
similarity_index['pval'] = [i[1] for i in similarity_index[0]]
similarity_index['h'] = 1 * (similarity_index.pval < 0.05)
               
ttest_random = sp.stats.ttest_1samp(similarity_index['r'], 0)
ttest_rep = sp.stats.ttest_1samp(similarity_index[similarity_index.group == 1]['r'], 0)
ttest_alt = sp.stats.ttest_1samp(similarity_index[similarity_index.group == -1]['r'], 0)
         
#%% old stuff

# for v in plot_vars:
        
#     plt.close('all')
#     # original hue for 4 types of sequences
#     fig, ax = plt.subplots(nrows=1, ncols=2, figsize=(3,2), 
#                             sharex=True, sharey=True)

#     plt.xticks(range(0, 4), labels=[''] * 4)
#     sns.despine(trim=True)
#     plt.tight_layout()
#     fig.savefig(os.path.join(mypath, 'Figures', 'sequences_akaishi_%s.pdf'%v))

# #%% correlate
# for n in neural_var:


# #%% PLOT ALL THE VARIABLES with their template numbers

# # import matplotlib as mpl
# # mpl.rcParams['mathtext.fontset'] = 'cm'

# # for vars in ['beta_3motor_lat_refwin', 'criterion', 'presp', 'pstim']:
#     plt.close('all')
#     fig, ax = plt.subplots(nrows=1, ncols=2, figsize=(3.5,2), 
#                         sharex=True, sharey=True)
#     kwargs = {'x':'nr_reps', 'y':vars,
#           'hue':'hue', 'hue_order':[1, 0, -2, -1], # make sure the colors make sense
#           'palette':'Paired',
#           'err_style':'bars', 
#           'zorder':200, 'legend':False}
#     # first the lines only
#     sns.lineplot(data=df_sequences.loc[df_sequences.repeaters == False],
#               ax=ax[0], markers=False, alpha=0.3, ci=95,
#               **kwargs)
#     sns.lineplot(data=df_sequences.loc[df_sequences.repeaters == True],
#               ax=ax[1], markers=False, alpha=0.3, ci=95,
#               **kwargs)
#     # now overlay the templates as markers
#     mrk = ['$' + s + '$' for s in df_sequences.template2.unique()]
#     sns.lineplot(data=df_sequences.loc[df_sequences.repeaters == False],
#               ax=ax[0], style='template2', style_order=df_sequences.template2.unique(),
#               markers=mrk, mec=None, mfc='auto', ms=10, ci=False,
#               **kwargs)
#     sns.lineplot(data=df_sequences.loc[df_sequences.repeaters == True],
#               ax=ax[1], style='template2', style_order=df_sequences.template2.unique(),
#               markers=mrk, mec=None, mfc='auto', ms=10, ci=False,
#               **kwargs)
    
#     # horizontal lines
#     if (vars == 'presp') or (vars == 'pstim'):
#         ax[0].axhline(0.5, color='darkgrey', ls=':', zorder=-100)
#         ax[1].axhline(0.5, color='darkgrey', ls=':', zorder=-100)
#     else:
#         ax[0].axhline(0, color='darkgrey', ls=':', zorder=-100)
#         ax[1].axhline(0, color='darkgrey', ls=':', zorder=-100)
        
#     ax[0].set(#ylabel='P(response A)', 
#           xlabel='Choice history',
#           title='')
#     ax[1].set(xlabel='Choice history',
#           title='',
#           xlim=[-0.3, 4])
#     plt.xticks(range(0, 4), labels=[''] * 4)
#     plt.tight_layout()
#     sns.despine(trim=True)
#     fig.savefig(os.path.join(mypath, 'Figures', 'sequences_%s.pdf'%vars))


