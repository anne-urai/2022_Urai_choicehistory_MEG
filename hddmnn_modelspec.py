import hddm
import statsmodels.formula.api as sm

# ============================================ #
# MODEL SPECIFICATION
# ============================================ #

# logistic link function for starting point
# dont use: https://groups.google.com/g/hddm-users/c/k8dUBepPyl8/m/8HuUjLOBAAAJ?hl=en
# def z_link_func(x):
#     return 1 / (1 + np.exp(-(x.values.ravel())))

def remove_stim_fluct(data, varname):

    fitted = sm.ols("%s ~ 1 + stimulus"%varname, data=data).fit()
    data[varname + '_resid'] = fitted.resid
    return data


def make_model(data, mname):

    print('making HDDMnn model %s'% mname)

    # in case we're using simulated data
    if not 'stimulus' in data.columns:
        data['stimulus'] = data['S']

    #%% ============================================ #
    # DDMs - replicate https://github.com/anne-urai/MEG/blob/master/hddm_modelspec_regression.py
    # but use the HDDMnn extension
    # ============================================ #

    if mname == 'ddm_nohist':
                
        v_reg = {'model': 'v ~ 1 + stimulus', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1', 'link_func': lambda x:x}
        
        model = 'ddm' # start simple
        hddmnn_model = hddm.HDDMnnRegressor(data,
                                   [v_reg, z_reg],
                                   model = model,
                                   include = hddm.simulators.model_config[model]['hddm_include'],
                                   p_outlier = 0.05,
                                   is_group_model = True, # hierarchical model, parameters per subject
                                   group_only_regressors = False,
                                   informative = False)

    elif mname == 'ddm_prevresp':
        
        v_reg = {'model': 'v ~ 1 + stimulus + prevresp', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + prevresp', 'link_func': lambda x: x}
        
        model = 'ddm' # start simple
        hddmnn_model = hddm.HDDMnnRegressor(data,
                                   [v_reg, z_reg],
                                   model = model,
                                   include = hddm.simulators.model_config[model]['hddm_include'],
                                   p_outlier = 0.05,
                                   is_group_model = True,
                                   group_only_regressors=False,
                                   informative = False)
        
    #%% ============================================ #
    # DDMs with neural data
    # ============================================ #

    elif mname == 'ddm_ips23gamma':
        
        data.dropna(subset=['gamma_ips23_stimwin'], inplace=True)

        v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin', 'link_func': lambda x: x}
        
        model = 'ddm' # start simple
        hddmnn_model = hddm.HDDMnnRegressor(data,
                                   [v_reg, z_reg],
                                   model = model,
                                   include = hddm.simulators.model_config[model]['hddm_include'],
                                   p_outlier = 0.05,
                                   is_group_model = True,
                                   group_only_regressors=False,
                                   informative = False)

    elif mname == 'ddm_ips01alpha':
        
        data.dropna(subset=['alpha_ips01_stimwin_resid'], inplace=True)

        v_reg = {'model': 'v ~ 1 + stimulus + alpha_ips01_stimwin_resid', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + alpha_ips01_stimwin_resid', 'link_func': lambda x: x}
        
        model = 'ddm' # start simple
        hddmnn_model = hddm.HDDMnnRegressor(data,
                                   [v_reg, z_reg],
                                   model = model,
                                   include = hddm.simulators.model_config[model]['hddm_include'],
                                   p_outlier = 0.05,
                                   is_group_model = True,
                                   group_only_regressors=False,
                                   informative = False)

    elif mname == 'ddm_motorbeta':
        
        data.dropna(subset=['beta_3motor_lat_refwin'], inplace=True)

        v_reg = {'model': 'v ~ 1 + stimulus + beta_3motor_lat_refwin', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + beta_3motor_lat_refwin', 'link_func': lambda x: x}
        
        model = 'ddm' # start simple
        hddmnn_model = hddm.HDDMnnRegressor(data,
                                   [v_reg, z_reg],
                                   model = model,
                                   include = hddm.simulators.model_config[model]['hddm_include'],
                                   p_outlier = 0.05,
                                   is_group_model = True,
                                   group_only_regressors=False,
                                   informative = False)
        
    elif mname == 'ddm_twohist':
         
         data.dropna(subset=['gamma_ips23_stimwin', 
                           'beta_3motor_lat_refwin'], inplace=True)

         v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin + beta_3motor_lat_refwin', 'link_func': lambda x:x}
         z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin + beta_3motor_lat_refwin', 'link_func': lambda x: x}
         
         model = 'ddm' # start simple
         hddmnn_model = hddm.HDDMnnRegressor(data,
                                    [v_reg, z_reg],
                                    model = model,
                                    include = hddm.simulators.model_config[model]['hddm_include'],
                                    p_outlier = 0.05,
                                    is_group_model = True,
                                    group_only_regressors=False,
                                    informative = False)     
        
    elif mname == 'ddm_allhist':
         
         data.dropna(subset=['gamma_ips23_stimwin', 'alpha_ips01_stimwin_resid',
                           'beta_3motor_lat_refwin'], inplace=True)

         v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin + alpha_ips01_stimwin_resid + beta_3motor_lat_refwin', 'link_func': lambda x:x}
         z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin + alpha_ips01_stimwin_resid + beta_3motor_lat_refwin', 'link_func': lambda x: x}
         
         model = 'ddm' # start simple
         hddmnn_model = hddm.HDDMnnRegressor(data,
                                    [v_reg, z_reg],
                                    model = model,
                                    include = hddm.simulators.model_config[model]['hddm_include'],
                                    p_outlier = 0.05,
                                    is_group_model = True,
                                    group_only_regressors=False,
                                    informative = False)  
         
    elif mname == 'ddm_allhist_groupsplit':
         
         data.dropna(subset=['gamma_ips23_stimwin', 'alpha_ips01_stimwin_resid',
                           'beta_3motor_lat_refwin'], inplace=True)
    
         v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin:(-1 + C(group, Treatment(1))) ' + 
                  '+ alpha_ips01_stimwin_resid:(-1 + C(group, Treatment(1))) ' +
                  '+ beta_3motor_lat_refwin:(-1 + C(group, Treatment(1)))', 'link_func': lambda x:x}
         z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin:(-1 + C(group, Treatment(1))) ' +
                  ' + alpha_ips01_stimwin_resid:(-1 + C(group, Treatment(1))) ' +
                  ' + beta_3motor_lat_refwin:(-1 + C(group, Treatment(1)))', 'link_func': lambda x: x}
         
         model = 'ddm' # start simple
         hddmnn_model = hddm.HDDMnnRegressor(data,
                                    [v_reg, z_reg],
                                    model = model,
                                    include = hddm.simulators.model_config[model]['hddm_include'],
                                    p_outlier = 0.05,
                                    is_group_model = True,
                                    group_only_regressors=False,
                                    informative = False)  
         
    elif mname == 'ddm_allhist_groupint':
         
         data.dropna(subset=['gamma_ips23_stimwin', 'alpha_ips01_stimwin_resid',
                           'beta_3motor_lat_refwin'], inplace=True)
    
         v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin*group ' + 
                  '+ alpha_ips01_stimwin_resid*group ' +
                  '+ beta_3motor_lat_refwin*group', 'link_func': lambda x:x}
         z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin*group ' +
                  ' + alpha_ips01_stimwin_resid*group ' +
                  ' + beta_3motor_lat_refwin*group', 'link_func': lambda x: x}
         
         model = 'ddm' # start simple
         hddmnn_model = hddm.HDDMnnRegressor(data,
                                    [v_reg, z_reg],
                                    model = model,
                                    include = hddm.simulators.model_config[model]['hddm_include'],
                                    p_outlier = 0.05,
                                    is_group_model = True,
                                    group_only_regressors=False,
                                    informative = False)  

     #%% ============================================ #
     # Linearly collapsing 'angle' model
     # ============================================ #

    elif mname == 'angle_nohist':
             
     v_reg = {'model': 'v ~ 1 + stimulus', 'link_func': lambda x:x}
     z_reg = {'model': 'z ~ 1', 'link_func': lambda x:x}
     
     model = 'angle' # start simple
     hddmnn_model = hddm.HDDMnnRegressor(data,
                                [v_reg, z_reg],
                                model = model,
                                include = hddm.simulators.model_config[model]['hddm_include'],
                                p_outlier = 0.05,
                                is_group_model = True, # hierarchical model, parameters per subject
                                group_only_regressors = False,
                                informative = False)

    elif mname == 'angle_prevresp':
     
     v_reg = {'model': 'v ~ 1 + stimulus + prevresp', 'link_func': lambda x:x}
     z_reg = {'model': 'z ~ 1 + prevresp', 'link_func': lambda x: x}
     
     model = 'angle' # start simple
     hddmnn_model = hddm.HDDMnnRegressor(data,
                                [v_reg, z_reg],
                                model = model,
                                include = hddm.simulators.model_config[model]['hddm_include'],
                                p_outlier = 0.05,
                                is_group_model = True,
                                group_only_regressors=False,
                                informative = False)
     
    #%% ============================================ #
    # Angle with neural data
    # ============================================ #

    elif mname == 'angle_ips23gamma':
     
     data.dropna(subset=['gamma_ips23_stimwin'], inplace=True)

     v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin', 'link_func': lambda x:x}
     z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin', 'link_func': lambda x: x}
     
     model = 'angle' # start simple
     hddmnn_model = hddm.HDDMnnRegressor(data,
                                [v_reg, z_reg],
                                model = model,
                                include = hddm.simulators.model_config[model]['hddm_include'],
                                p_outlier = 0.05,
                                is_group_model = True,
                                group_only_regressors=False,
                                informative = False)

    elif mname == 'angle_ips01alpha':
     
     data.dropna(subset=['alpha_ips01_stimwin_resid'], inplace=True)

     v_reg = {'model': 'v ~ 1 + stimulus + alpha_ips01_stimwin_resid', 'link_func': lambda x:x}
     z_reg = {'model': 'z ~ 1 + alpha_ips01_stimwin_resid', 'link_func': lambda x: x}
     
     model = 'angle' # start simple
     hddmnn_model = hddm.HDDMnnRegressor(data,
                                [v_reg, z_reg],
                                model = model,
                                include = hddm.simulators.model_config[model]['hddm_include'],
                                p_outlier = 0.05,
                                is_group_model = True,
                                group_only_regressors=False,
                                informative = False)

    elif mname == 'angle_motorbeta':
     
     data.dropna(subset=['beta_3motor_lat_refwin'], inplace=True)

     v_reg = {'model': 'v ~ 1 + stimulus + beta_3motor_lat_refwin', 'link_func': lambda x:x}
     z_reg = {'model': 'z ~ 1 + beta_3motor_lat_refwin', 'link_func': lambda x: x}
     
     model = 'angle' # start simple
     hddmnn_model = hddm.HDDMnnRegressor(data,
                                [v_reg, z_reg],
                                model = model,
                                include = hddm.simulators.model_config[model]['hddm_include'],
                                p_outlier = 0.05,
                                is_group_model = True,
                                group_only_regressors=False,
                                informative = False)
     
    elif mname == 'angle_twohist':
      
      data.dropna(subset=['gamma_ips23_stimwin', 
                        'beta_3motor_lat_refwin'], inplace=True)

      v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin + beta_3motor_lat_refwin', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin + beta_3motor_lat_refwin', 'link_func': lambda x: x}
      
      model = 'angle' # start simple
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)     
     
    elif mname == 'angle_allhist':
      
      data.dropna(subset=['gamma_ips23_stimwin', 'alpha_ips01_stimwin_resid',
                        'beta_3motor_lat_refwin'], inplace=True)

      v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin + alpha_ips01_stimwin_resid + beta_3motor_lat_refwin', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin + alpha_ips01_stimwin_resid + beta_3motor_lat_refwin', 'link_func': lambda x: x}
      
      model = 'angle' # start simple
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)      

    elif mname == 'angle_allhist_groupsplit':
     
        data.dropna(subset=['gamma_ips23_stimwin', 'alpha_ips01_stimwin_resid',
        'beta_3motor_lat_refwin'], inplace=True)
        
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin:(-1 + C(group, Treatment(1))) ' + 
         '+ alpha_ips01_stimwin_resid:(-1 + C(group, Treatment(1))) ' +
         '+ beta_3motor_lat_refwin:(-1 + C(group, Treatment(1)))', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin:(-1 + C(group, Treatment(1))) ' +
         ' + alpha_ips01_stimwin_resid:(-1 + C(group, Treatment(1))) ' +
         ' + beta_3motor_lat_refwin:(-1 + C(group, Treatment(1)))', 'link_func': lambda x: x}
         
        model = 'angle' # start simple
        hddmnn_model = hddm.HDDMnnRegressor(data,
                       [v_reg, z_reg],
                         model = model,
                         include = hddm.simulators.model_config[model]['hddm_include'],
                         p_outlier = 0.05,
                         is_group_model = True,
                         group_only_regressors=False,
                         informative = False)  
  
    elif mname == 'angle_allhist_groupint':
     
        data.dropna(subset=['gamma_ips23_stimwin', 'alpha_ips01_stimwin_resid',
        'beta_3motor_lat_refwin'], inplace=True)
        
        v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin*group ' + 
         '+ alpha_ips01_stimwin_resid*group ' +
         '+ beta_3motor_lat_refwin*group', 'link_func': lambda x:x}
        z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin*group ' +
         ' + alpha_ips01_stimwin_resid*group ' +
         ' + beta_3motor_lat_refwin*group', 'link_func': lambda x: x}
         
        model = 'angle' # start simple
        hddmnn_model = hddm.HDDMnnRegressor(data,
                       [v_reg, z_reg],
                         model = model,
                         include = hddm.simulators.model_config[model]['hddm_include'],
                         p_outlier = 0.05,
                         is_group_model = True,
                         group_only_regressors=False,
                         informative = False)  
        
    elif mname == 'angle_allhist_bound':
      
      data.dropna(subset=['gamma_ips23_stimwin', 'alpha_ips01_stimwin_resid',
                        'beta_3motor_lat_refwin'], inplace=True)

      v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin + alpha_ips01_stimwin_resid + beta_3motor_lat_refwin', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin + alpha_ips01_stimwin_resid + beta_3motor_lat_refwin', 'link_func': lambda x: x}
      theta_reg = {'model': 'theta ~ 1 + gamma_ips23_stimwin + alpha_ips01_stimwin_resid + beta_3motor_lat_refwin', 'link_func': lambda x: x}

      model = 'angle' # start simple
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg, theta_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)  
      
    #%% ============================================ #
    # WEIBULL, nonlinear bound collapse with neural data
    # ============================================ #

    elif mname == 'weibull_nohist':


      v_reg = {'model': 'v ~ 1 + stimulus', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1', 'link_func': lambda x: x}
      
      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)   
 
    elif mname == 'weibull_prevresp':

      v_reg = {'model': 'v ~ 1 + stimulus + prevresp', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + prevresp', 'link_func': lambda x: x}
      
      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)   
      
    elif mname == 'weibull_twohist':
      
      data.dropna(subset=['gamma_ips23_stimwin', 
                        'beta_3motor_lat_refwin'], inplace=True)

      v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin + beta_3motor_lat_refwin', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin + beta_3motor_lat_refwin', 'link_func': lambda x: x}
      
      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)    
      
    elif mname == 'weibull_allhist':
      
      data.dropna(subset=['gamma_ips23_stimwin', 'alpha_ips01_stimwin_resid',
                        'beta_3motor_lat_refwin'], inplace=True)

      v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin + alpha_ips01_stimwin_resid + beta_3motor_lat_refwin', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin + alpha_ips01_stimwin_resid + beta_3motor_lat_refwin', 'link_func': lambda x: x}
      
      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)     
      
    elif mname == 'weibull_allhist2':
      
      data.dropna(subset=['gamma_ips23_stimwin', 'alpha_ips01_stimwin_resid',
                        'beta_3motor_lat_refwin'], inplace=True)

      v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin + alpha_ips01_stimwin_resid + beta_3motor_lat_refwin', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin + alpha_ips01_stimwin_resid + beta_3motor_lat_refwin', 'link_func': lambda x: x}
      
      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)     
      
    elif mname == 'weibull_allhist_prevresp':
      
      data.dropna(subset=['gamma_ips23_stimwin', 'alpha_ips01_stimwin_resid',
                        'beta_3motor_lat_refwin'], inplace=True)

      v_reg = {'model': 'v ~ 1 + stimulus + prevresp + ' + 
               'gamma_ips23_stimwin + alpha_ips01_stimwin_resid + ' + 
               'beta_3motor_lat_refwin', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + prevresp + ' + 
               'gamma_ips23_stimwin + alpha_ips01_stimwin_resid + ' + 
               'beta_3motor_lat_refwin', 'link_func': lambda x: x}
      
      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)   
      
      ## Weibull supplementary figures

    elif mname == 'weibull_bound':
      
      data.dropna(subset=['gamma_ips23_stimwin', 'alpha_ips01_stimwin_resid',
                        'beta_3motor_lat_refwin'], inplace=True)

      a_reg = {'model': 'a ~ 1 + gamma_ips23_stimwin + alpha_ips01_stimwin_resid + beta_3motor_lat_refwin', 'link_func': lambda x: x}

      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [a_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)   
      
    elif mname == 'weibull_bound_prevchoice':
      
      data.dropna(subset=['prevresp'], inplace=True)

      a_reg = {'model': 'a ~ 1 + prevresp', 'link_func': lambda x: x}

      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [a_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)   
      
    elif mname == 'weibull_allhist_bound':
      
      data.dropna(subset=['gamma_ips23_stimwin', 'alpha_ips01_stimwin_resid',
                        'beta_3motor_lat_refwin'], inplace=True)

      v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin + alpha_ips01_stimwin_resid + beta_3motor_lat_refwin', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin + alpha_ips01_stimwin_resid + beta_3motor_lat_refwin', 'link_func': lambda x: x}
      a_reg = {'model': 'a ~ 1 + gamma_ips23_stimwin + alpha_ips01_stimwin_resid + beta_3motor_lat_refwin', 'link_func': lambda x: x}

      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg, a_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)   
      
      
    elif mname == 'weibull_allhist_groupsplit':
      
      data.dropna(subset=['gamma_ips23_stimwin', 'alpha_ips01_stimwin_resid',
                        'beta_3motor_lat_refwin'], inplace=True) 
      
      v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin:(-1 + C(group, Treatment(1))) ' + 
         '+ alpha_ips01_stimwin_resid:(-1 + C(group, Treatment(1))) ' +
         '+ beta_3motor_lat_refwin:(-1 + C(group, Treatment(1)))', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin:(-1 + C(group, Treatment(1))) ' +
         ' + alpha_ips01_stimwin_resid:(-1 + C(group, Treatment(1))) ' +
         ' + beta_3motor_lat_refwin:(-1 + C(group, Treatment(1)))', 'link_func': lambda x: x}
    
      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)  
      
    elif mname == 'weibull_allhist_groupint':
      
      data.dropna(subset=['gamma_ips23_stimwin', 'alpha_ips01_stimwin_resid',
                        'beta_3motor_lat_refwin'], inplace=True) 
      
      v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin*group' + 
         '+ alpha_ips01_stimwin_resid*group ' +
         '+ beta_3motor_lat_refwin*group', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin*group ' +
         ' + alpha_ips01_stimwin_resid*group ' +
         ' + beta_3motor_lat_refwin*group', 'link_func': lambda x: x}
    
      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)  
      
      
    elif mname == 'weibull_ips23_refwin':
      
      data.dropna(subset=['gamma_ips23_refwin'], inplace=True) 
      
      v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_refwin', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + gamma_ips23_refwin', 'link_func': lambda x: x}
    
      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)  

    elif mname == 'weibull_ips23_resid':
      
      data.dropna(subset=['gamma_ips23_stimwin'], inplace=True) 
      data = data.groupby(['subj_idx', 'session']).apply(remove_stim_fluct,
                                                    varname='gamma_ips23_stimwin')
      
      v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin_resid', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin_resid', 'link_func': lambda x: x}
    
      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)  
      
    elif mname == 'weibull_ips23_prevresp':
      
      data.dropna(subset=['gamma_ips23_stimwin'], inplace=True) 
      
      v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin + prevresp', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin + prevresp', 'link_func': lambda x: x}
    
      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)  
      
    elif mname == 'weibull_ips23_prevresp_repeaters':
      
      data.dropna(subset=['gamma_ips23_stimwin'], inplace=True) 
      data = data[data.group == 1] # only repeaters

      v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin + prevresp', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin + prevresp', 'link_func': lambda x: x}
    
      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)  
      
    elif mname == 'weibull_ips23_prevresp_alternators':
      
      data.dropna(subset=['gamma_ips23_stimwin'], inplace=True) 
      data = data[data.group == -1] # only repeaters

      v_reg = {'model': 'v ~ 1 + stimulus + gamma_ips23_stimwin + prevresp', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + gamma_ips23_stimwin + prevresp', 'link_func': lambda x: x}
    
      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)  
      
    elif mname == 'weibull_motor_prestimwin':
      
      data.dropna(subset=['beta_3motor_lat_prestimwin'], inplace=True) 
      
      v_reg = {'model': 'v ~ 1 + stimulus + beta_3motor_lat_prestimwin', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + beta_3motor_lat_prestimwin', 'link_func': lambda x: x}
    
      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)  
      
    elif mname == 'weibull_motor_stimwin':
      
      data.dropna(subset=['beta_3motor_lat_stimwin'], inplace=True) 
      
      v_reg = {'model': 'v ~ 1 + stimulus + beta_3motor_lat_stimwin', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + beta_3motor_lat_stimwin', 'link_func': lambda x: x}
    
      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)  
      
    elif mname == 'weibull_motor_prevresp':
      
      data.dropna(subset=['beta_3motor_lat_refwin'], inplace=True) 
      
      v_reg = {'model': 'v ~ 1 + stimulus + beta_3motor_lat_refwin + prevresp', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + beta_3motor_lat_refwin + prevresp', 'link_func': lambda x: x}
    
      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)  
 
    elif mname == 'weibull_motor_prevresp_repeaters':
      
      data.dropna(subset=['beta_3motor_lat_refwin'], inplace=True) 
      data = data[data.group == 1] # only repeaters

      v_reg = {'model': 'v ~ 1 + stimulus + beta_3motor_lat_refwin + prevresp', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + beta_3motor_lat_refwin + prevresp', 'link_func': lambda x: x}
    
      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)  

    elif mname == 'weibull_motor_prevresp_alternators':
      
      data.dropna(subset=['beta_3motor_lat_refwin'], inplace=True) 
      data = data[data.group == -1] # only repeaters

      v_reg = {'model': 'v ~ 1 + stimulus + beta_3motor_lat_refwin + prevresp', 'link_func': lambda x:x}
      z_reg = {'model': 'z ~ 1 + beta_3motor_lat_refwin + prevresp', 'link_func': lambda x: x}
    
      model = 'weibull' # nonlinear bound collapse, captured by 2 parameters
      hddmnn_model = hddm.HDDMnnRegressor(data,
                                 [v_reg, z_reg],
                                 model = model,
                                 include = hddm.simulators.model_config[model]['hddm_include'],
                                 p_outlier = 0.05,
                                 is_group_model = True,
                                 group_only_regressors=False,
                                 informative = False)  
      
    else:
        # throw a warning
        print('%s is undefined!'%mname)

    return hddmnn_model
