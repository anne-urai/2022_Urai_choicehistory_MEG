%% 2-interval forced choice random dots
% Staircase to check their MOCS result, should converge quickly
%
% Edited: Anne Urai, 26 May 2015
% -----------------------------------------------------------------

clear all; close all; clc;
cd C:\Users\eeg-lab\Desktop\AnneUrai\2IFC_RDK_UKE;
addpath(genpath(pwd));

path_ptb = fullfile('C:\Users\eeg-lab\Desktop\TACSATT\Hannah\myPTB');
addpath(genpath(path_ptb));

% general setup
setup.Eye           = false; % true if using Eyelink
setup.MEG           = false; % true if sending triggers to the MEG
setup.cancel        = false; % becomes true if escape is pressed, will abort experiment (but save data)
setup.training      = false; % will increase the nr of trials, no pupil rebound, and save under different filename
setup.thresholding  = true;

% ask for subject number, default: 0
setup.participant       = input('Participant number? ');
if isempty(setup.participant), setup.participant = 0; end

setup.inGerman          = input('Instructions in German? ');
if isempty(setup.inGerman), setup.inGerman = 1; end % German = default

%% load data we have already
load(sprintf('Data/P%d_threshold.mat', setup.participant));
setup.threshold = fit1.threshold;

% use the uncorrected Weibull points
x = log10(datapoints1.mean.difficulty) - log10(fit1.threshold);
y = datapoints1.mean.correct;

% fit the psychometric function as QUEST likes it to get parameters
p2 = @(x, beta, delta, gamma, xThreshold) ...
    delta*gamma+(1-delta)*(1-(1-gamma)*exp(-10.^(beta*(x-xThreshold))));

% define logLikelihood of the cumulative WB
LL_p2 = @(x, beta, delta, gamma, xThreshold, y) ...
    -sum(y.*log(p2(x, beta, delta, gamma, xThreshold))...
    + (1-y).*log(1-p2(x, beta, delta, gamma, xThreshold)));

% function evaluation params
options.MaxFunEvals = 5000000;
options.MaxIter     = 500000;
options.TolX        = 0.00000001;
options.TolFun      = 0.00000001;
options             = optimset('Display', 'off') ;
options.Robust      = 'on';

% initial values for fminsearch
guessbeta(1) = 3.5; % slope
guessbeta(2) = 0.01; % lapse rate
guessbeta(3) = .5; % 50%
guessbeta(4) = log(fit1.threshold);

% lower bound of params
lowerbound(1)   = 0;
lowerbound(2)   = 0;
lowerbound(3)   = 0.5;
lowerbound(4)   = -Inf;

% upper bound of params
upperbound(1)   = +inf;
upperbound(2)   = .05;
upperbound(3)   = 0.5;
upperbound(4)   = +Inf;

% find optimal values for beta using fminsearch
[questfit.beta, questfit.fval] = fminsearchbnd(@(beta) LL_p2(x, ...
    beta(1), beta(2), beta(3), beta(4), datapoints1.mean.correct), guessbeta, lowerbound, upperbound, options);

% create the QUEST structure
pThreshold = 0.70; % we want the threshold at this level
beta=3.5; delta=0.01 ; gamma=0.5;% from Watson and Pelli

tGuess = questfit.beta(4);
tGuessSd = 10; % what is a good guess for the standard deviation?

q = QuestCreate(tGuess,tGuessSd,pThreshold,beta,delta,gamma, [], [], 1);
hold on; plot(x, y, '*');
waitforbuttonpress; % check if this looks OK
q.normalizePdf = 1; % This adds a few ms per call to QuestUpdate, but otherwise the pdf will underflow after about 1000 trials.

%% Setup the PsychToolbox
window.dist             = 60; % viewing distance in cm , 60 in EEG lab
window.width            = 53.5; % physical width of the screen in cm, 53.5 for BENQ in EEG lab
window.height           = 30; % physical height of the screen in cm, 42 for the MEG projector screen inside the scanner
window.skipChecks       = 1; % set to 1 to skip VBL tests and avoid warnings
[window, audio]         = SetupPTB_EEGlab(window); %load all the psychtoolbox things
if setup.MEG,           window.cogent = cogent;  end %save information about the io details
if setup.Eye,           ELconfig(window); end

Screen('TextSize', window.h, 20);
Screen('TextFont', window.h, 'Trebuchet');
Screen('TextColor', window.h, [255 255 255] );

DrawFormattedText(window.h, 'Loading...',  'center', 'center');
Screen('Flip', window.h);
[setup, dots, fix, results, sound, flip, trigger] = configuration_staircase_2IFC(window, audio, setup);

CedrusResponseBox('CloseAll');
IOPort('CloseAll');
setup.responsebox = CedrusResponseBox('Open', 'COM9');
evt = [];

%% Start looping through the blocks and trials
for block = 1:setup.nblocks,
    
    DrawFormattedText(window.h, 'Loading...',  'center', 'center');
    Screen('Flip', window.h);
    
    % preload all the dot coordinates - overwrite this block!
    coord.ref           = nan(1, setup.ntrials, setup.nframes, 2, dots.nDots);
    coord.stim          = nan(1, setup.ntrials, setup.nframes, 2, dots.nDots);
    
    Screen('FillRect', window.h, [0 0 0]);
    
    if setup.inGerman,
        DrawFormattedText(window.h, ['Da Sie jetzt wissen, was zu tun ist werden wir nun genau die Aufgabe üben, die Sie im MEG Scanner durchführen werden.\n \n' ...
            ' Die Unterschiede zu der Aufgabe, die Sie zuvor bearbeitet haben sind: \n \n\n \n' ...
            ' 1. Es gibt keine wirklich leichten Versuchsdurchgänge mehr. \n \n\n \n' ...
            ' 2. Vor und nach dem Feedbackton werden Sie ein zufälliges Flackern auf dem Bildschirm sehen. \n \n' ...
            ' Bitte fixieren Sie weiter und blinzeln Sie während dieser Zeit nicht. Warten Sie auf den Ton. \n \n\n \n' ...
            ' 3. Ein paar Sekunden nach dem Feedbackton werden die Punkte aufhören, sich zu bewegen. \n \n' ...
            ' Dies ist Ihre BLINZELPAUSE, in der Sie mit den Augen blinzeln dürfen. \n \n\n \n\n \n ' ...
            ' Nach dieser kurzen Pause, drücken Sie eine Taste um zum nächsten Versuchsdurchgänge zu gelangen.'], ...
            'center', 'center');
    else
        DrawFormattedText(window.h, ['Now that you know what to do, we will practice the exact task you will do in the MEG scanner.\n \n' ...
            ' The differences with the task you did before are \n \n\n \n' ...
            ' 1. there are no more really easy trials. \n \n\n \n' ...
            ' 2. before and after the feedback tone, you will see random flicker on the screen. \n \n' ...
            ' Please keep fixating and do not blink during this time, and wait for the tone. \n \n\n \n' ...
            ' 3. Some seconds after the feedback tone, the dots will stop moving. \n \n' ...
            ' This is your BLINK BREAK, in which you may blink your eyes. \n \n\n \n\n \n ' ...
            ' Whenever you are ready, you can press any button \n \n to continue to the next trial.'], ...
            'center', 'center');
    end
    Screen('Flip', window.h);
    CedrusResponseBox('WaitButtonPress', setup.responsebox);
    WaitSecs(.1);
    
    % display instructions
    if setup.participant > 0,
        switch mod(setup.participant, 2);
            case 0
                switch setup.feedbackcounterbalance(setup.participant),
                    case 1
                        if setup.inGerman,
                            DrawFormattedText(window.h, ['Drücken Sie links für eine schwächere \n \n' ...
                                '  und rechts für eine stärkere Bewegung im zweiten Interval. \n \n' ...
                                '  Sie werden einen hohen Ton für richtige Anworten hören, \n \n' ...
                                '  und einen tiefen Ton für falsche Antworten. \n \n '
                                ' Wenn Sie die Taste zu früh oder zu spät drücken, \n \n' ...
                                ' wird die Antwort als Fehler gewertet und hören Sie eine längere Fehlerton. \n \n\n \n Viel Erfolg!'],  'center', 'center');
                        else
                            DrawFormattedText(window.h, ['Respond by pressing left for weaker \n \n' ...
                                ' and right for stronger motion in the second interval. \n \n' ...
                                ' You will hear a high beep for correct responses, \n \n' ...
                                ' and a low beep for errors. \n \n,'...
                                ' If you press too early or too late, you will hear a longer error tone. \n \n', ...
                                '\n \n\n \n Good luck!'],  'center', 'center');
                        end
                    case 2
                        if setup.inGerman,
                            DrawFormattedText(window.h, ['Drücken Sie links für eine schwächere \n \n' ...
                                '  und rechts für eine stärkere Bewegung im zweiten Interval. \n \n' ...
                                '  Sie werden einen tiefen Ton für richtige Anworten hören, \n \n '
                                ' Wenn Sie die Taste zu früh oder zu spät drücken, \n \n' ...
                                ' wird die Antwort als Fehler gewertet und hören Sie eine längere Fehlerton. \n \n\n \n Viel Erfolg!'],  'center', 'center');
                        else
                            DrawFormattedText(window.h, ['Respond by pressing left for weaker \n \n' ...
                                ' and right for stronger motion in the second interval. \n \n' ...
                                ' You will hear a low beep for correct responses, \n \n' ...
                                ' and a high beep for errors. \n \n,'...
                                ' If you press too early or too late, you will hear a longer error tone. \n \n', ...
                                '\n \n\n \n Good luck!'],  'center', 'center');
                        end
                end
            case 1
                switch setup.feedbackcounterbalance(setup.participant),
                    case 1
                        if setup.inGerman,
                            DrawFormattedText(window.h, ['Drücken Sie rechts für eine schwächere \n \n' ...
                                '  und links für eine stärkere Bewegung im zweiten Interval. \n \n' ...
                                '  Sie werden einen hohen Ton für richtige Anworten hören, \n \n' ...
                                '  und einen tiefen Ton für falsche Antworten. \n \n\n \n\n \n Viel Erfolg!'],  'center', 'center');
                        else
                            DrawFormattedText(window.h, ['Respond by pressing right for weaker \n \n' ...
                                ' and left for stronger motion in the second interval. \n \n' ...
                                ' You will hear a high beep for correct responses, \n \n' ...
                                ' and a low beep for errors. \n \n\n \n\n \n Good luck!'],  'center', 'center');
                        end
                    case 2
                        if setup.inGerman,
                            DrawFormattedText(window.h, ['Drücken Sie rechts für eine schwächere \n \n' ...
                                '  und links für eine stärkere Bewegung im zweiten Interval. \n \n' ...
                                '  Sie werden einen tiefen Ton für richtige Anworten hören, \n \n' ...
                                '  und einen hohen Ton für falsche Antworten. \n \n\n \n\n \n Viel Erfolg!'],  'center', 'center');
                        else
                            DrawFormattedText(window.h, ['Respond by pressing right for weaker \n \n' ...
                                ' and left for stronger motion in the second interval. \n \n' ...
                                ' You will hear a low beep for correct responses, \n \n' ...
                                ' and a high beep for errors. \n \n\n \n\n \n Good luck!'],  'center', 'center');
                        end
                end
        end
        Screen('Flip', window.h);
        WaitSecs(.1);
        CedrusResponseBox('WaitButtonPress', setup.responsebox);
        WaitSecs(.1);
    end
    
    %% start the loop over trials
    
    % run until 100 reversals took place
    nrofreversals = 0;
    state         = 0; % to measure reversals easily
    setup.requiredNrReversals = 20;
    
    %  while nrofreversals < setup.requiredNrReversals,
    
    for trial = 1:setup.ntrials,
        
        if trial == 1, % draw new dots, otherwise keep the ones from the last trial
            window      = dots_noise_draw(window, dots);
            window      = drawFixation(window, fix, dots); %fixation
            Screen('Flip', window.h); % flip once, so stationary dots
            results.breaktimestart(block, trial) = GetSecs;
        end
        
        %% compute the coherence level based on the staircase
        tTest = QuestQuantile(q);	% Recommended by Pelli (1987), and still our favorite.
        
        coherence =  10.^tTest + fit1.threshold;
        % impose limit
        if coherence > .3,
            coherence = .3;
        end
        % transform into our % coherence
        setup.coherence(block, trial) = coherence;
        
        % see where we're going
        if trial > 1,
            if setup.coherence(block, trial) > setup.coherence(block, trial-1),
                newstate = 1; % up
            elseif setup.coherence(block, trial) < setup.coherence(block, trial-1);
                newstate = -1; % down
            end
        else
            newstate = 0;
        end
        
        % test if there was a reversal
        if newstate ~= state,
            nrofreversals = nrofreversals + 1;
            state = newstate;
        end
        
        % NOW START PRESENTING THIS STIMULUS
        % replace the dots.coherence field
        dots.coherence(block, trial)  = setup.baselinecoh + setup.increment(block, trial).* setup.coherence(block, trial);
        
        % preload all the dot coordinates before starting this trial
        coord.ref(1, trial, :, :, :)        = dots_refstim(setup, window, dots, block, trial);
        coord.stim(1, trial, :, :, :)       = dots_limitedlifetime(setup, window, dots, block, trial);
        
        % BLINK BREAK - WAIT FOR BUTTONPRESS
        CedrusResponseBox('WaitButtonPress', setup.responsebox);
        
        % FIXATION
        for frameNum = 1:ceil(setup.fixtime(block, trial)*window.frameRate),
            
            window      = dots_noise_draw(window, dots);
            window      = drawFixation(window, fix, dots); % fixation
            
            [flip.fix.VBL(block, trial, frameNum), ...
                flip.fix.StimOns(block, trial, frameNum), ...
                flip.fix.FlipTS(block, trial, frameNum), ...
                flip.fix.Missed(block, trial, frameNum), ...
                flip.fix.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
        end
        
        % play reference stimulus onset tone
        PsychPortAudio('SetLoop',audio.h, sound.tonepos(1,1), sound.tonepos(1,2));
        PsychPortAudio('Start', audio.h); %like flip
        
        % REFERECE STIMULUS with 70% coherence
        for frameNum = 1:setup.nframes,
            
            window      = drawAllDots(window, dots, 1, trial, coord.ref, frameNum);
            window      = drawFixation(window, fix, dots); % fixation
            
            [flip.refstim.VBL(block, trial, frameNum), ...
                flip.refstim.StimOns(block, trial, frameNum), ...
                flip.refstim.FlipTS(block, trial, frameNum), ...
                flip.refstim.Missed(block, trial, frameNum), ...
                flip.refstim.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
        end
        
        % INTERVAL
        for frameNum = 1:ceil(setup.intervaltime(block, trial)*window.frameRate),
            
            window      = dots_noise_draw(window, dots);
            window      = drawFixation(window, fix, dots); % fixation
            
            [flip.interval.VBL(block, trial, frameNum), ...
                flip.interval.StimOns(block, trial, frameNum), ...
                flip.interval.FlipTS(block, trial, frameNum), ...
                flip.interval.Missed(block, trial, frameNum), ...
                flip.interval.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
        end
        
        % play test stimulus onset tone
        PsychPortAudio('SetLoop',audio.h, sound.tonepos(1,1), sound.tonepos(1,2));
        PsychPortAudio('Start', audio.h); %like flip
        
        % TEST STIMULUS
        for frameNum = 1:setup.nframes,
            window      = drawAllDots(window, dots, 1, trial, coord.stim, frameNum);
            window      = drawFixation(window, fix, dots);
            
            [flip.stim.VBL(block, trial, frameNum), ...
                flip.stim.StimOns(block, trial, frameNum), ...
                flip.stim.FlipTS(block, trial, frameNum), ...
                flip.stim.Missed(block, trial, frameNum), ...
                flip.stim.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
        end
        
       %% RESPONSE
        frameNum = 1; keyIsDown = false; evt = [];
        CedrusResponseBox('FlushEvents', setup.responsebox);
        
        while GetSecs-flip.stim.VBL(block,trial,setup.nframes) < setup.resptime && isempty(evt),
            % when no response has been given, and the maximum response time hasnt been reached
            
            window      = dots_noise_draw(window, dots);
            window      = drawFixation(window, fix, dots); % fixation
            
            % record response
            evt = CedrusResponseBox('GetButtons', setup.responsebox);
            
            [flip.resptime.VBL(block, trial, frameNum), ...
                flip.resptime.StimOns(block, trial, frameNum), ...
                flip.resptime.FlipTS(block, trial, frameNum), ...
                flip.resptime.Missed(block, trial, frameNum), ...
                flip.resptime.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
            frameNum = frameNum + 1;
        end %button pressed
        
        %disp(evt);
        
        if ~isempty(evt),
            
            results.resptime(block, trial)      = GetSecs();
            results.RT(block, trial)            = results.resptime(block, trial) - flip.stim.VBL(block,trial, setup.nframes);
            results.press{block, trial}         = evt;
            
            switch mod(setup.participant, 2);
                case 0 %Screen('DrawText',window.h,  'Press left for weaker and right for stronger motion',  window.center(1)*0.60, window.center(2)*0.55 , [255 255 255] );
                    switch evt.buttonID
                        case 'left', % left target 1, right target 2
                            results.response(block, trial) = -1;
                        case 'right',
                            results.response(block, trial) = 1;
                        case 'ESCAPE', % if escape is pressed, exit the experiment
                            setup.cancel = true;
                            results.response(block, trial) = NaN;
                        case 'esc', % if escape is pressed, exit the experiment
                            setup.cancel = true;
                            results.response(block, trial) = NaN;
                        otherwise % if any other key was pressed, fill in a NaN
                            results.response(block, trial) = NaN;
                    end
                case 1  %Screen('DrawText',window.h,  'Press left for stronger and right for weaker motion',  window.center(1)*0.60, window.center(2)*0.55 , [255 255 255] );
                    switch evt.buttonID
                        case 'left', % left target 1, right target 2
                            results.response(block, trial) = 1;
                        case 'right',
                            results.response(block, trial) = -1;
                        case 'ESCAPE', % if escape is pressed, exit the experiment
                            setup.cancel = true;
                            results.response(block, trial) = NaN;
                        case 'esc', % if escape is pressed, exit the experiment
                            setup.cancel = true;
                            results.response(block, trial) = NaN;
                        otherwise % if any other key was pressed, fill in a NaN
                            results.response(block, trial) = NaN;
                    end
            end
        else
            %if no key was pressed, NaN
            results.response(block, trial)      = NaN;
            results.resptime(block, trial)      = GetSecs(); % to know when to start counting for pupilrebound
        end
        
        % code for correct responses
        if results.response(block, trial) == setup.increment(block,trial), %whether motion is stronger than 50% or not
            results.correct(block,trial) = true;
        elseif isnan(results.response(block, trial)),
            results.correct(block,trial) = NaN;
            results.RT(block,trial) = NaN; %set RT to NaN to easily filter out trials without a response
        else results.correct(block,trial) = false;
        end
        
        % WAIT FOR THE PUPIL TO RETURN TO BASELINE
        frameNum = 1;
        while GetSecs < setup.pupilreboundtime(block, trial)+ results.resptime(block, trial);
            
            window      = dots_noise_draw(window, dots);
            window      = drawFixation(window, fix, dots); % fixation
            
            [flip.pupilrebound1.VBL(block, trial, frameNum), ...
                flip.pupilrebound1.StimOns(block, trial, frameNum), ...
                flip.pupilrebound1.FlipTS(block, trial, frameNum), ...
                flip.pupilrebound1.Missed(block, trial, frameNum), ...
                flip.pupilrebound1.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
            frameNum = frameNum + 1;
        end
        
        KbQueueStop();
        
        %% FEEDBACK
        
        if results.correct(block,trial) == true, %correct
            PsychPortAudio('SetLoop',audio.h, sound.tonepos(2,1), sound.tonepos(2,2));
        elseif results.correct(block,trial) == false, %incorrect
            PsychPortAudio('SetLoop',audio.h, sound.tonepos(3,1), sound.tonepos(3,2));
        elseif isnan(results.correct(block,trial)), %no response given
            PsychPortAudio('SetLoop',audio.h, sound.tonepos(4,1), sound.tonepos(4,2));
        else %unrecognized response
            setup.cancel = true;
            warning('could not determine which feedback to give');
        end
        
        results.feedbackonset(block, trial) = GetSecs;
        results.soundstart.feedback(block, trial) = PsychPortAudio('Start', audio.h);
        
        % wait for the pupil to return to baseline, average 3s
        frameNum = 1;
        while GetSecs < setup.pupilreboundtime2(block, trial)+ results.feedbackonset(block, trial);
            window      = dots_noise_draw(window, dots);
            window      = drawFixation(window, fix, dots); % fixation
            
            [flip.pupilrebound2.VBL(block, trial, frameNum), ...
                flip.pupilrebound2.StimOns(block, trial, frameNum), ...
                flip.pupilrebound2.FlipTS(block, trial, frameNum), ...
                flip.pupilrebound2.Missed(block, trial, frameNum), ...
                flip.pupilrebound2.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
            frameNum = frameNum + 1;
        end
        
        % UPDATE QUEST STRUCTURE
        if ~isnan(results.correct(block, trial)),
            q = QuestUpdate(q, tTest, results.correct(block, trial)); % Add the new datum (actual test intensity and observer response) to the database.
        end
        
        % break out of all trials if ESC was pressed
        if setup.cancel,
            break
            warning('experiment was manually terminated');
        end
        
    end %end trial loop
    %  end
    
    if block < setup.nblocks,
        DrawFormattedText(window.h, sprintf('Finished block %d! \n \n You answered %.2f percent of trials correct, \n \n and your average reaction time was %.2f seconds. \n \n\n \n Press any key to continue.', ...
            block, nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:))), 'center', 'center');
    else % finish
        DrawFormattedText(window.h, sprintf('Finished block %d! \n \n You answered %.2f percent of trials correct, \n \n and your average reaction time was %.2f seconds. \n \n\n \n Please call the experimenter.', ...
            block, nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:))), 'center', 'center');
    end
    Screen('Flip', window.h);
    
    % also show this info in the command window
    fprintf('Finished block %d! \n \n You answered %.2f percent of trials correct, \n \n and your average reaction time was %.2f seconds.', ...
        block, nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:)));
    
    % save all the dot coordinates
    save(sprintf('Data/Dots_P%d_threshold_b%d_%s.mat', setup.participant, block, datestr(now, 'yyyy-mm-dd_HH-MM-SS')), '-mat', '-v7.3');
    
        CedrusResponseBox('WaitButtonPress', setup.responsebox);
    
    % break out of all blocks if ESC was pressed
    if setup.cancel == true,
        break
        warning('experiment was manually terminated');
    end
    
end %end block loop

% wrap up and save
setup.datetime = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
% create subject specific file and save - add unique datestring to avoid any overwriting of files
setup.filename = sprintf('Data/P%d_staircase_%s.mat', setup.participant, setup.datetime);
save(setup.filename, '-mat', 'setup', 'window', 'dots', 'fix', 'results', 'audio',  'sound', 'flip', 'trigger');

disp('SAVED FILE TO DISK'); disp(setup.filename);

% exit gracefully
disp('done!'); Screen('CloseAll'); ShowCursor;
PsychPortAudio('Stop', audio.h);
sca;

t=QuestMean(q);		% Recommended by Pelli (1989) and King-Smith et al. (1994). Still our favorite.
coherence = 10.^t + fit1.threshold;
sd=QuestSd(q);

clf;plot(setup.coherence(:), 'd');
title(sprintf('Final threshold estimate (mean/sd) is %.4f / %.4f\n',coherence,sd));

%save the fig
set(gcf,'PaperOrientation','landscape');
set(gcf,'PaperUnits','normalized');
set(gcf,'PaperPosition', [0 0 1 1]);
saveas(gcf, sprintf('Data/Staircase_P%d.png', setup.participant), 'png');

%% save this final threshold on the eeglab computer
seventypercentthreshold = coherence;
save(sprintf('Data/P%d_threshold.mat', setup.participant), 'seventypercentthreshold', 'fit1', 'fit2', 'fit3', 'datapoints1', 'datapoints3');
