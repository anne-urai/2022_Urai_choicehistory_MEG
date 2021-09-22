function [ setup ] = staircase( setup, results, block, trial )
% based on the trial history, select a new response for the upcoming trial

stepsize = 0.001; % 1/10 percent coherence

if block == 1 && trial < 3,
    % take the outcome of the MOCS as a beginning
    setup.coherence(block, trial) = setup.threshold;
    
elseif block == 2 && trial < 3,
    % start block 2 where block1 left off
    setup.coherence(block, trial) = setup.coherence(block-1, end);
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
