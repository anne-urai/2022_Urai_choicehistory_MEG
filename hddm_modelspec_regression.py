import pandas as pd
import numpy as np
import scipy as sp
import sys, os, glob
import pickle
import math

# import matplotlib
# matplotlib.use('Agg') # to still plot even when no display is defined
# import matplotlib.pyplot as plt
# import seaborn as sns
import statsmodels.formula.api as sm

# more handy imports
from IPython import embed as shell
import hddm, kabuki

# ============================================ #
# MODEL SPECIFICATION
# ============================================ #

# logistic link function for starting point
def z_link_func(x):
    return 1 / (1 + np.exp(-(x.values.ravel())))

# def remove_stim_fluct(data, varname):
#
#     fitted = sm.ols("%s ~ 1 + stimulus"%varname, data=data).fit()
#     data[varname + '_resid'] = fitted.resid
#     return data


def make_model_fromvar(data, varname):

    # make sure there are no NaNs so the model can run
    data.dropna(subset=[varname], inplace=True)

    # specify the model flexibly
    v_reg = {'model': 'v ~ 1 + stimulus + ' + varname, 'link_func': lambda x:x}
    z_reg = {'model': 'z ~ 1 + ' + varname, 'link_func': z_link_func}
    m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
                           group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    return m


def make_model_fromvar_prevfb(data, varname):

    # split out regressors into prev-correct and prev-error
    # data['preverror'] = ~(data.prev_correct).astype(bool)
    data['prevcorrect'] = (data.prev_correct).astype(bool)

    # varname has '_prevfb' appended, remove
    varname = varname[:-7]

    # make sure there are no NaNs so the model can run
    data.dropna(subset=[varname], inplace=True)

    # specify the model flexibly
    v_reg = {'model': 'v ~ 1 + stimulus + prevcorrect:%s'%varname, 'link_func': lambda x:x}
    z_reg = {'model': 'z ~ 1 + prevcorrect:%s'%varname, 'link_func': z_link_func}
    m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
                           group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    return m


def make_model_fromvar_prevchoice(data, varname):

    # varname has '_prevchoice' appended, remove
    varname = varname[:-11]

    # make sure there are no NaNs so the model can run
    data.dropna(subset=[varname], inplace=True)

    # specify the model flexibly
    v_reg = {'model': 'v ~ 1 + stimulus + prevresp + %s'%varname, 'link_func': lambda x:x}
    z_reg = {'model': 'z ~ 1 + prevresp + %s'%varname, 'link_func': z_link_func}
    m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
                           group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    return m

def make_model(data, mname):

    print('making HDDM model %s'% mname)

    # # ====================================== #
    # # flip motor lateralization between handgroups
    # data['handgroup'] = ((data.subj_idx % 2) == 0) # see subjectspecifics.m
    # # change the 0 group around, so all point in L = -1, R = +1
    # cols2flip = [c for c in data.columns if 'lateralized' in c]
    # for c in cols2flip:
    #     data.loc[data.handgroup == 0, c] *= -1  # flip values around

    # ====================================== #

    if mname == 'nohist':
        v_reg = {'model': 'v ~ 1 + stimulus', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    if mname == 'allhist':

        data.dropna(subset=['gamma_ips23_stimwin', 'alpha_ips01_stimwin_resid',
                            'beta_3motor_lat_refwin'], inplace=True)

        # this will be run after handgroups have already been flipped
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin + ' +
                 'alpha_ips01_stimwin_resid + beta_3motor_lat_refwin',
                 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin + ' +
                 'alpha_ips01_stimwin_resid + beta_3motor_lat_refwin',
                 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    if mname == 'allhist_postcorr':

        # remove previous error trials
        data = data.loc[data.prev_correct == 1, :]

        data.dropna(subset=['gamma_ips23_stimwin', 'alpha_ips01_stimwin_resid',
                            'beta_3motor_lat_refwin'], inplace=True)

        # this will be run after handgroups have already been flipped
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin + ' +
                 'alpha_ips01_stimwin_resid + beta_3motor_lat_refwin',
                 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin + ' +
                 'alpha_ips01_stimwin_resid + beta_3motor_lat_refwin',
                 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    if mname == 'allhist_posterr':

        # remove previous error trials
        data = data.loc[data.prev_correct == 0, :]

        data.dropna(subset=['gamma_ips23_stimwin', 'alpha_ips01_stimwin_resid',
                            'beta_3motor_lat_refwin'], inplace=True)

        # this will be run after handgroups have already been flipped
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin + ' +
                 'alpha_ips01_stimwin_resid + beta_3motor_lat_refwin',
                 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin + ' +
                 'alpha_ips01_stimwin_resid + beta_3motor_lat_refwin',
                 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    if mname == 'hist_betagamma':

        data.dropna(subset=['gamma_ips23_stimwin',
                            'beta_3motor_lat_refwin'], inplace=True)

        # this will be run after handgroups have already been flipped
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin + ' +
                 'beta_3motor_lat_refwin',
                 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin + ' +
                 'beta_3motor_lat_refwin',
                 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    if mname == 'hist_betagamma_1param':

        data.dropna(subset=['gamma_ips23_stimwin',
                            'beta_3motor_lat_refwin'], inplace=True)

        # this will be run after handgroups have already been flipped
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin',
                 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + beta_3motor_lat_refwin',
                 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)


    if mname == 'hist_betagamma_postcorr':

        # remove previous error trials
        data = data.loc[data.prev_correct == 1, :]

        data.dropna(subset=['gamma_ips23_stimwin',
                            'beta_3motor_lat_refwin'], inplace=True)

        # this will be run after handgroups have already been flipped
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin + ' +
                 'beta_3motor_lat_refwin',
                 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin + ' +
                 'beta_3motor_lat_refwin',
                 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    if mname == 'hist_betagamma_posterr':

        # remove previous error trials
        data = data.loc[data.prev_correct == 0, :]

        data.dropna(subset=['gamma_ips23_stimwin',
                            'beta_3motor_lat_refwin'], inplace=True)

        # this will be run after handgroups have already been flipped
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin + ' +
                 'beta_3motor_lat_refwin',
                 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin + ' +
                 'beta_3motor_lat_refwin',
                 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)


    elif mname == 'hist_gamma':

        data.dropna(subset=['gamma_ips23_stimwin'], inplace=True)

        # FULL MODEL WHERE ALL TERMS COMPETE
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)


    # ============================================ #
    # PREVIOUS CHOICE
    elif mname == 'prevchoice_dcz':

        # now use previous outcome (coded as in Busse)
        v_reg = {'model': 'v ~ 1 + stimulus + prevresp', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + prevresp', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'prevchoice_dc':

        # now use previous outcome (coded as in Busse)
        v_reg = {'model': 'v ~ 1 + stimulus + prevresp', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'prevchoice_z':

        # now use previous outcome (coded as in Busse)
        v_reg = {'model': 'v ~ 1 + stimulus', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + prevresp', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    # ============================================ #
    # MODELS WITH NEURAL REGRESSORS
    # 1. IPS2/3 GAMMA AND IPS0/1 ALPHA

    elif mname == 'gamma_ips23prestim_v':

        data.dropna(subset=['gamma_wang_vfc_IPS23_prestimtimewin'], inplace=True)      

        v_reg = {'model': 'v ~ 1 + stimulus + gamma_wang_vfc_IPS23_prestimtimewin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'gamma_ips23prestim_z':

        data.dropna(subset=['gamma_wang_vfc_IPS23_prestimtimewin'], inplace=True)      

        v_reg = {'model': 'v ~ 1 + stimulus', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_wang_vfc_IPS23_prestimtimewin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'gamma_ips23prestim_vz':

        data.dropna(subset=['gamma_wang_vfc_IPS23_prestimtimewin'], inplace=True)      

        v_reg = {'model': 'v ~ 1 + stimulus + gamma_wang_vfc_IPS23_prestimtimewin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_wang_vfc_IPS23_prestimtimewin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'alpha_ips01prestim_v':

        data.dropna(subset=['alpha_wang_vfc_IPS01_prestimtimewin'], inplace=True)      

        v_reg = {'model': 'v ~ 1 + stimulus + alpha_wang_vfc_IPS01_prestimtimewin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'alpha_ips01prestim_z':

        data.dropna(subset=['alpha_wang_vfc_IPS01_prestimtimewin'], inplace=True)      

        v_reg = {'model': 'v ~ 1 + stimulus', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + alpha_wang_vfc_IPS01_prestimtimewin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'alpha_ips01prestim_vz':

        data.dropna(subset=['alpha_wang_vfc_IPS01_prestimtimewin'], inplace=True)      

        v_reg = {'model': 'v ~ 1 + stimulus + alpha_wang_vfc_IPS01_prestimtimewin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + alpha_wang_vfc_IPS01_prestimtimewin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    # ============================================ #
    # GAMMA AND ALPHA DURING STIMULUS WINDOW
    # ============================================ #

    elif mname == 'gamma_ips23stim_vz':

        data.dropna(subset=['gamma_wang_vfc_IPS23_stimuluswin'], inplace=True)

        # FULL MODEL WHERE ALL TERMS COMPETE
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_wang_vfc_IPS23_stimuluswin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_wang_vfc_IPS23_stimuluswin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'alpha_ips01stim_vz':

        data.dropna(subset=['alpha_wang_vfc_IPS01_stimuluswin'], inplace=True)     

        # FULL MODEL WHERE ALL TERMS COMPETE
        v_reg = {'model': 'v ~ 1 + stimulus + alpha_wang_vfc_IPS01_stimuluswin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + alpha_wang_vfc_IPS01_stimuluswin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)
        
    elif mname == 'gamma_ips23stim_vz_nostimpred':

        data.dropna(subset=['gamma_wang_vfc_IPS23_stimuluswin'], inplace=True)     

        # FULL MODEL WHERE ALL TERMS COMPETE
        v_reg = {'model': 'v ~ 1 + gamma_wang_vfc_IPS23_stimuluswin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_wang_vfc_IPS23_stimuluswin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)


    elif mname == 'alpha_ips01stim_vz_nostimpred':

        data.dropna(subset=['alpha_wang_vfc_IPS01_stimuluswin'], inplace=True)     

        # FULL MODEL WHERE ALL TERMS COMPETE
        v_reg = {'model': 'v ~ 1 + alpha_wang_vfc_IPS01_stimuluswin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + alpha_wang_vfc_IPS01_stimuluswin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)
        

    elif mname == 'gammaresid_ips23stim_vz':

        data.dropna(subset=['gamma_wang_vfc_IPS23_stimuluswin'], inplace=True)
        data = data.groupby(['subj_idx', 'session']).apply(remove_stim_fluct,
                                                    varname='gamma_wang_vfc_IPS23_stimuluswin')

        # FULL MODEL WHERE ALL TERMS COMPETE
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_wang_vfc_IPS23_stimuluswin_resid', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_wang_vfc_IPS23_stimuluswin_resid', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'alpharesid_ips01stim_vz':

        data.dropna(subset=['alpha_wang_vfc_IPS01_stimuluswin'], inplace=True)
        data = data.groupby(['subj_idx', 'session']).apply(remove_stim_fluct,
                                                    varname='alpha_wang_vfc_IPS01_stimuluswin')

        # FULL MODEL WHERE ALL TERMS COMPETE
        v_reg = {'model': 'v ~ 1 + stimulus + alpha_wang_vfc_IPS01_stimuluswin_resid', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + alpha_wang_vfc_IPS01_stimuluswin_resid', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)
    
    # SPLIT BY PREVIOUS TRIAL OUTCOME
    elif mname == 'gamma_ips23stim_prevfbSum_vz':

        data.dropna(subset=['gamma_wang_vfc_IPS23_stimuluswin'], inplace=True)
        v_reg = {'model': 'v ~ 1 + stimulus + ' +
                          'gamma_wang_vfc_IPS23_stimuluswin * C(prev_correct, Sum(0))',
                 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + ' +
                          'gamma_wang_vfc_IPS23_stimuluswin * C(prev_correct, Sum(0))',
                 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'alpha_ips01stim_prevfbSum_vz':

        data.dropna(subset=['alpha_wang_vfc_IPS01_stimuluswin'], inplace=True)
        v_reg = {'model': 'v ~ 1 + stimulus + ' +
                          'alpha_wang_vfc_IPS01_stimuluswin * C(prev_correct, Sum(0))',
                 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + ' +
                          'alpha_wang_vfc_IPS01_stimuluswin * C(prev_correct, Sum(0))',
                 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    # SPLIT BY PREVIOUS TRIAL OUTCOME
    elif mname == 'gamma_ips23stim_prevfbTreat_vz':

        data.dropna(subset=['gamma_wang_vfc_IPS23_stimuluswin'], inplace=True)
        v_reg = {'model': 'v ~ 1 + stimulus + ' +
                          'gamma_wang_vfc_IPS23_stimuluswin * C(prev_correct, Treatment(1))',
                 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + ' +
                          'gamma_wang_vfc_IPS23_stimuluswin * C(prev_correct, Treatment(1))',
                 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'alpha_ips01stim_prevfbTreat_vz':

        data.dropna(subset=['alpha_wang_vfc_IPS01_stimuluswin'], inplace=True)
        v_reg = {'model': 'v ~ 1 + stimulus + ' +
                          'alpha_wang_vfc_IPS01_stimuluswin * C(prev_correct, Treatment(1))',
                 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + ' +
                          'alpha_wang_vfc_IPS01_stimuluswin * C(prev_correct, Treatment(1))',
                 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'gamma_ips23stim_prevcorrect_vz':

        data.dropna(subset=['gamma_wang_vfc_IPS23_stimuluswin'], inplace=True)
        data3 = data.loc[data.prev_correct == 0, :] # remove previous error trials

        # FULL MODEL WHERE ALL TERMS COMPETE
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_wang_vfc_IPS23_stimuluswin', 'link_func': lambda x: x}
        z_reg = {'model': 'z ~ 1 + gamma_wang_vfc_IPS23_stimuluswin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
                               group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'alpha_ips01stim_prevcorrect_vz':

        data.dropna(subset=['alpha_wang_vfc_IPS01_stimuluswin'], inplace=True)
        data = data.loc[data.prev_correct == 1, :] # remove previous error trials

        # FULL MODEL WHERE ALL TERMS COMPETE
        v_reg = {'model': 'v ~ 1 + stimulus + alpha_wang_vfc_IPS01_stimuluswin', 'link_func': lambda x: x}
        z_reg = {'model': 'z ~ 1 + alpha_wang_vfc_IPS01_stimuluswin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
                               group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'gamma_ips23stim_preverror_vz':

        data.dropna(subset=['gamma_wang_vfc_IPS23_stimuluswin'], inplace=True)
        data = data.loc[data.prev_correct == 0, :] # remove previous error trials

        # FULL MODEL WHERE ALL TERMS COMPETE
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_wang_vfc_IPS23_stimuluswin', 'link_func': lambda x: x}
        z_reg = {'model': 'z ~ 1 + gamma_wang_vfc_IPS23_stimuluswin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
                               group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'alpha_ips01stim_preverror_vz':

        data.dropna(subset=['alpha_wang_vfc_IPS01_stimuluswin'], inplace=True)
        data = data.loc[data.prev_correct == 0, :] # remove previous error trials

        # FULL MODEL WHERE ALL TERMS COMPETE
        v_reg = {'model': 'v ~ 1 + stimulus + alpha_wang_vfc_IPS01_stimuluswin', 'link_func': lambda x: x}
        z_reg = {'model': 'z ~ 1 + alpha_wang_vfc_IPS01_stimuluswin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
                               group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    # ============================================ #
    # THE TWO BELOW ARE USED IN COMBINATION WITH prevchoice_dc FOR MEDIATION ANALYSIS

    elif mname == 'prevchoice_gamma_ips23stim_v':

        data.dropna(subset=['gamma_wang_vfc_IPS23_stimuluswin'], inplace=True)     

        v_reg = {'model': 'v ~ 1 + stimulus + gamma_wang_vfc_IPS23_stimuluswin + prevresp', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'prevchoice_alpha_ips01_v':

        data.dropna(subset=['alpha_wang_vfc_IPS01_stimuluswin'], inplace=True)     

        v_reg = {'model': 'v ~ 1 + stimulus + alpha_wang_vfc_IPS01_stimuluswin + prevresp', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 ', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'prevchoice_alpha_ips01stim_z':

        data.dropna(subset=['alpha_wang_vfc_IPS01_stimuluswin'], inplace=True)     

        v_reg = {'model': 'v ~ 1 + stimulus', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + prevresp + alpha_wang_vfc_IPS01_stimuluswin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'prevchoice_gammaresid_ips23stim_v':

        data.dropna(subset=['gamma_wang_vfc_IPS23resid_stimuluswin'], inplace=True)        

        v_reg = {'model': 'v ~ 1 + stimulus + gamma_wang_vfc_IPS23resid_stimuluswin + prevresp', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'prevchoice_alpharesid_ips01_v':

        data.dropna(subset=['alpha_wang_vfc_IPS01resid_stimuluswin'], inplace=True)        

        v_reg = {'model': 'v ~ 1 + stimulus + alpha_wang_vfc_IPS01resid_stimuluswin + prevresp', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 ', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)


    # ============================================ #
    # MEDIATION ANALYSIS WITH SIMULTANEOUS V AND Z

    elif mname == 'prevchoice_gamma_ips23stim_vz':

        data.dropna(subset=['gamma_wang_vfc_IPS23_stimuluswin'], inplace=True)     

        v_reg = {'model': 'v ~ 1 + stimulus + gamma_wang_vfc_IPS23_stimuluswin + prevresp', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_wang_vfc_IPS23_stimuluswin + prevresp', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'prevchoice_alpha_ips01_vz':

        data.dropna(subset=['alpha_wang_vfc_IPS01_stimuluswin'], inplace=True)     

        v_reg = {'model': 'v ~ 1 + stimulus + alpha_wang_vfc_IPS01_stimuluswin + prevresp', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + alpha_wang_vfc_IPS01_stimuluswin + prevresp', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'prevchoice_gammaresid_ips23stim_vz':

        data.dropna(subset=['gamma_wang_vfc_IPS23resid_stimuluswin'], inplace=True)        

        v_reg = {'model': 'v ~ 1 + stimulus + gamma_wang_vfc_IPS23resid_stimuluswin + prevresp', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_wang_vfc_IPS23resid_stimuluswin + prevresp', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'prevchoice_alpharesid_ips01stim_vz':

        data.dropna(subset=['alpha_wang_vfc_IPS01resid_stimuluswin'], inplace=True)        
 
        v_reg = {'model': 'v ~ 1 + stimulus + alpha_wang_vfc_IPS01resid_stimuluswin + prevresp', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + alpha_wang_vfc_IPS01resid_stimuluswin + prevresp', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    # ============================================ #
    # 3. INCLUDE MOTOR BETA
    # ============================================ #

    elif mname == 'beta_motor_v':

        data.dropna(subset=['beta_jwg_M1_lateralized_prestimtimewin'], inplace=True)
        v_reg = {'model': 'v ~ 1 + stimulus + beta_jwg_M1_lateralized_prestimtimewin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'beta_motor_z':

        data.dropna(subset=['beta_jwg_M1_lateralized_prestimtimewin'], inplace=True)
        v_reg = {'model': 'v ~ 1 + stimulus', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + beta_jwg_M1_lateralized_prestimtimewin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'beta_m1_refwin_vz':

        data.dropna(subset=['beta_jwg_M1_lateralized_referencewin'], inplace=True)
        v_reg = {'model': 'v ~ 1 + stimulus + beta_jwg_M1_lateralized_referencewin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + beta_jwg_M1_lateralized_referencewin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'beta_m1_prestim_vz':

        data.dropna(subset=['beta_jwg_M1_lateralized_prestimtimewin'], inplace=True)
        v_reg = {'model': 'v ~ 1 + stimulus + beta_jwg_M1_lateralized_prestimtimewin', 'link_func': lambda x: x}
        z_reg = {'model': 'z ~ 1 + beta_jwg_M1_lateralized_prestimtimewin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
                       group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'beta_m1_stim_vz':

        data.dropna(subset=['beta_jwg_M1_lateralized_stimuluswin'], inplace=True)
        v_reg = {'model': 'v ~ 1 + stimulus + beta_jwg_M1_lateralized_stimuluswin', 'link_func': lambda x: x}
        z_reg = {'model': 'z ~ 1 + beta_jwg_M1_lateralized_stimuluswin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
                       group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'beta_aips_refwin_vz':

        data.dropna(subset=['beta_jwg_aIPS_lateralized_referencewin'], inplace=True)
        v_reg = {'model': 'v ~ 1 + stimulus + beta_jwg_aIPS_lateralized_referencewin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + beta_jwg_aIPS_lateralized_referencewin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'beta_aips_prestim_vz':

        data.dropna(subset=['beta_jwg_aIPS_lateralized_prestimtimewin'], inplace=True)
        v_reg = {'model': 'v ~ 1 + stimulus + beta_jwg_aIPS_lateralized_prestimtimewin', 'link_func': lambda x: x}
        z_reg = {'model': 'z ~ 1 + beta_jwg_aIPS_lateralized_prestimtimewin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
                       group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'beta_aips_stim_vz':

        data.dropna(subset=['beta_jwg_aIPS_lateralized_stimuluswin'], inplace=True)
        v_reg = {'model': 'v ~ 1 + stimulus + beta_jwg_aIPS_lateralized_stimuluswin', 'link_func': lambda x: x}
        z_reg = {'model': 'z ~ 1 + beta_jwg_aIPS_lateralized_stimuluswin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
                       group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'beta_pmdv_refwin_vz':

        data.dropna(subset=['gamma_glasser_premotor_lateralized_PMdv_referencewin'], inplace=True)
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_glasser_premotor_lateralized_PMdv_referencewin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_glasser_premotor_lateralized_PMdv_referencewin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'beta_pmdv_prestim_vz':

        data.dropna(subset=['gamma_glasser_premotor_lateralized_PMdv_prestimtimewin'], inplace=True)
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_glasser_premotor_lateralized_PMdv_prestimtimewin', 'link_func': lambda x: x}
        z_reg = {'model': 'z ~ 1 + gamma_glasser_premotor_lateralized_PMdv_prestimtimewin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
                       group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'beta_pmdv_stim_vz':

        data.dropna(subset=['gamma_glasser_premotor_lateralized_PMdv_stimuluswin'], inplace=True)
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_glasser_premotor_lateralized_PMdv_stimuluswin', 'link_func': lambda x: x}
        z_reg = {'model': 'z ~ 1 + gamma_glasser_premotor_lateralized_PMdv_stimuluswin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
                       group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'beta_pces_refwin_vz':

        data.dropna(subset=['gamma_jwg_IPS_PCeS_lateralized_referencewin'], inplace=True)
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_jwg_IPS_PCeS_lateralized_referencewin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_jwg_IPS_PCeS_lateralized_referencewin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'beta_pces_prestim_vz':

        data.dropna(subset=['gamma_jwg_IPS_PCeS_lateralized_prestimtimewin'], inplace=True)
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_jwg_IPS_PCeS_lateralized_prestimtimewin', 'link_func': lambda x: x}
        z_reg = {'model': 'z ~ 1 + gamma_jwg_IPS_PCeS_lateralized_prestimtimewin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
                       group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'beta_pces_stim_vz':

        data.dropna(subset=['gamma_jwg_IPS_PCeS_lateralized_stimuluswin'], inplace=True)
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_jwg_IPS_PCeS_lateralized_stimuluswin', 'link_func': lambda x: x}
        z_reg = {'model': 'z ~ 1 + gamma_jwg_IPS_PCeS_lateralized_stimuluswin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
                       group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    # ============================================ #
    # SET OF MODELS THAT SPLITS BY REPEATERS AND ALTERNATORS

    elif mname == 'prevchoice_dcz_repalt':

        # now use previous outcome (coded as in Busse)
        v_reg = {'model': 'v ~ 1 + stimulus + group*prevresp', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + group*prevresp', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'gamma_ips23_v_repalt':

        v_reg = {'model': 'v ~ 1 + stimulus + group*gamma_wang_vfc_IPS23_prestimtimewin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)
    
    elif mname == 'beta_motor_z_repalt':

        v_reg = {'model': 'v ~ 1 + stimulus', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + group*beta_jwg_M1_lateralized_prestimtimewin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'gamma_ips23_v_beta_motor_z_repalt':

        v_reg = {'model': 'v ~ 1 + stimulus + group*gamma_wang_vfc_IPS23_prestimtimewin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + group*beta_jwg_M1_lateralized_prestimtimewin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    elif mname == 'ref_beta_motor_vz_prestim_gamma_ips23_vz_repalt':

        v_reg = {'model': 'v ~ 1 + stimulus + group*gamma_wang_vfc_IPS23_prestimtimewin + group*beta_jwg_M1_lateralized_referencewin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + group*gamma_wang_vfc_IPS23_prestimtimewin + group*beta_jwg_M1_lateralized_referencewin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    # ======================== new models for the paper

    elif mname == 'gamma_ips23_alpha_ips01_stimulus_vz_repalt':

        v_reg = {'model': 'v ~ 1 + stimulus + group*gamma_wang_vfc_IPS23_stimuluswin + '
                          'group*alpha_wang_vfc_IPS01_stimuluswin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + group*gamma_wang_vfc_IPS23_stimuluswin + '
                           'group*alpha_wang_vfc_IPS01_stimuluswin', 'link_func': z_link_func}
        m = hddm.HDDMRegressor(data, [v_reg, z_reg], include=['z', 'sv'], group_only_nodes=['sv'],
            group_only_regressors=False, keep_regressor_trace=False, p_outlier=0.05)

    else:
        # throw a warning
        print('%s is undefined!'%mname)

    return m

