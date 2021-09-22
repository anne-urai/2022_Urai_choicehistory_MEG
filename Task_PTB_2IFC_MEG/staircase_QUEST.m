function [ setup ] = staircase_QUEST( setup, results, block, trial )
% based on the trial history, select a new response for the upcoming trial
% instead of a simple 3 up 1 down, use QUEST

stepsize = 0.001; % 1/10 percent coherence

if block == 1 && trial < 3,
    % take the outcome of the MOCS as a beginning
    setup.coherence(block, trial) = setup.threshold;
    
else
    % look at the last 2 trials and check if these were errors
    if results.correct(block, trial-1) == 1 && results.correct(block, trial-2) == 1;
        % 3 corrects in a row, make more difficult
        setup.coherence(block, trial) = setup.coherence(block, trial-1) - stepsize;
        
    elseif results.correct(block, trial-1) == 0;
        % on an error, make easier
        setup.coherence(block, trial) = setup.coherence(block, trial-1) + stepsize; 
    else % do nothing 
        setup.coherence(block, trial) = setup.coherence(block, trial-1);
        
    end
end

end

