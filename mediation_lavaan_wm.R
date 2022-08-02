# mixed-levelm logistic regression mediation using the 'lavaan' package
# Anne Urai, 2021

library("lavaan")
library("lavaanPlot")
library("semPlot")
set.seed(2021)

# load data
datapath <- '/Users/urai/Data/projects/0/neurodec/Data/MEG-PL/CSV'
mydata = read.csv(sprintf("%s/allsubjects_meg_lean.csv", datapath))

# make sure response is a logical array, so logistic regression is used!
mydata$response <- factor(mydata$response)

## fit alpha and gamma signals together as multiple mediation (with covariation)
mydata$gamma_stim <- mydata$gamma_ips23_stimwin #- mydata$gamma_ips23_refwin
# mydata$gamma_ref <- mydata$gamma_ips23_refwin
mydata$gamma_delay <- mydata$gamma_ips23_prestimwin - mydata$gamma_ips23_prerefwin

# drop nans
mydata <- subset(mydata, select=c(subj_idx, stimulus, response, 
                                  prevresp, prev_correct, gamma_stim, gamma_delay))
mydata <- na.omit(mydata)

## potentially take only previous correct or previous error trials
prevfeedback <- 'all'
if(prevfeedback == 'correct') {
  print('keeping only previous correct trials')
  mydata <- mydata[(mydata$prev_correct == 1),]
} else if(prevfeedback == 'error') {
  print('keeping only previous error trials')
  mydata <- mydata[(mydata$prev_correct == 0),]  
} else {
  print('keeping all trials')
}
  
# ============================= #

multipleMediation <- '
                      # first, define the regression equations
                      gamma_stim ~ a1 * prevresp + s1 * stimulus
                      gamma_delay ~ a2 * prevresp

                      response ~ b1 * gamma_stim + b2 * gamma_delay + c * prevresp + s0 * stimulus

                      # define the effects
                      indirect_gamma_stim := a1 * b1
                      indirect_gamma_delay := a2 * b2

                      direct    := c
                      total     := c + (a1 * b1) + (a2 * b2)
                      
                      # specify covariance between the two mediators
                      # https://paolotoffanin.wordpress.com/2017/05/06/multiple-mediator-analysis-with-lavaan/comment-page-1/
                      gamma_stim ~~ gamma_delay
                      '

# ============================= #
# loop over subjects
mediation_results  <- data.frame()

for ( subj in unique(c(mydata$subj_idx)) ) {
  tmpdata <- mydata[(mydata$subj_idx == subj),]
  fit <- sem(model = multipleMediation, 
             data = tmpdata, 
             ordered=c("response"),
             estimator='WLSMV')
  param_estimates <- parameterEstimates(fit, standardized = TRUE)

  # append to dataframe
  summ2 = as.data.frame(param_estimates)
  summ2$subj_idx <- subj
  mediation_results <- rbind(mediation_results, summ2) # append
  write.csv(mediation_results, sprintf("%s/mediation/lavaan_wm2_%s.csv", datapath, prevfeedback)) # write at each iteration
  print(subj)
  
}

lavaanPlot(model = fit, node_options = list(shape = "box", fontname = "Helvetica"), 
           edge_options = list(color = "grey"), coefs = FALSE)

# # ============================= #
# # alternative: properly specify the mixed effects structure!
# # NOPE, not implemented for ordered data (logistic regression). stick to single-subject approach for now.
