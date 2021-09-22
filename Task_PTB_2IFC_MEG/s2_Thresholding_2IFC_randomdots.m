%% 2-interval forced coice random dots
% Thresholding code at different coherence differences
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
if isempty(setup.inGerman), setup.inGerman = 1; end % English = default

%% Setup the PsychToolbox
window.dist             = 60; % viewing distance in cm , 60 in EEG lab
window.width            = 53.5; % physical width of the screen in cm, 53.5 for BENQ in EEG lab
window.height           = 30; % physical height of the screen in cm, 42 for the MEG projector screen inside the scanner
window.skipChecks       = 1; % set to 1 to skip VBL tests and avoid warnings
[window, audio]         = SetupPTB_EEGlab(window); %load all the psychtoolbox things

Screen('TextSize', window.h, 20);
Screen('TextFont', window.h, 'Trebuchet');
Screen('TextColor', window.h, [255 255 255] );

DrawFormattedText(window.h, 'Loading...',  'center', 'center');
Screen('Flip', window.h);
[setup, dots, fix, results, sound, flip, trigger] = configuration_threshold_2IFC(window, audio, setup);

CedrusResponseBox('CloseAll');
IOPort('CloseAll');
setup.responsebox = CedrusResponseBox('Open', 'COM9');
evt = [];

Screen('FillRect', window.h, [0 0 0]);
if setup.inGerman,
    DrawFormattedText(window.h, ['Da Sie das Experiment nun kennen, \n \n' ...
        ' werden wir jetzt mit einer Session weitermachen in der \n \n' ...
        'Sie Versuchsdurchgänge mit unterschiedlichen Schwierigkeitsgraden sehen. \n \n' ...
        ' Manchmal kann es sehr leicht sein, \n \n' ...
        'zu unterscheiden ob das zweite Interval stärker oder schwächer ist (wie im Beispiel), \n \n' ...
        ' in anderen Fällen können beide Intervall sehr ähnlich aussehen. \n \n' ...
        ' Wenn Sie sich unsicher sind, versuchen Sie zu raten. \n \n' ...
        ' Denken Sie nicht zu viel über Ihre Antwort nach, sondern folgen Sie ihrem ersten Eindruck. \n \n \n \n' ...
        ' Seien Sie nicht frustriert wenn die Versuchsdurchgänge manchmal sehr schwer sind! \n \n' ...
        ' Es ist am wichtigsten, dass Sie die leichtesten richtig beantworten,\n \n' ...
        '  und dass Sie bei den anderen Ihr bestes geben.'],  'center', 'center');
else
    DrawFormattedText(window.h, ['Now that you know the task to do, \n \n' ...
        ' we will do a session in which you will see trials of varying difficulty. \n \n' ...
        ' Sometimes it might be very easy \n \n' ...
        ' to see if the second interval was stronger or weaker (as in the examples), \n \n' ...
        ' other times they might look quite similar to you. \n \n' ...
        ' Even if you are not sure, try to guess. \n \n' ...
        ' Do not think too much about your answer, but go with the first feeling. \n \n \n \n' ...
        ' Do not be frustrated if the trials are hard sometimes! \n \n' ...
        ' Most important is that you get the easiest ones correct,\n \n' ...
        '  and that you do your best on the others.'],  'center', 'center');
end
Screen('Flip', window.h);
CedrusResponseBox('WaitButtonPress', setup.responsebox);
if setup.inGerman,
    DrawFormattedText(window.h, ['In dieser Session, werden Sie nach Ihrer Antwort kein feedback bekommen. \n \n' ...
        ' Nach einer kurzen Pause beginnt der nächste Versuchsdurchgang automatisch. \n \n' ...
        ' Es gibt fünf Blöcke, die jeweils ca. 7 Minuten dauern. \n \n' ...
        ' Nach jedem Block werden Sie Ihre durchschnittliche Leistung und Reaktionszeit auf dem Bildschirm sehen. '],  'center', 'center');
else
    DrawFormattedText(window.h, ['In this session, you will not receive feedback after your response, \n \n' ...
        ' and after a short break the next trail will start automatically. \n \n' ...
        ' There will be five blocks, each lasting around 7 minutes. \n \n' ...
        ' After each block, you will see your average performance and reaction speed on the screen. '],  'center', 'center');
end
Screen('Flip', window.h);
CedrusResponseBox('WaitButtonPress', setup.responsebox);

% display instructions
if setup.participant > 0,
    switch mod(setup.participant, 2);
        case 0
            if setup.inGerman,
                DrawFormattedText(window.h, ['Drücken Sie links für eine schwächere \n \n' ...
                    '  und rechts für eine stärkere Bewegung im zweiten Interval. \n \n' ...
                    '  \n \n\n \n\n \n Viel Erfolg!'],  'center', 'center');
            else
                DrawFormattedText(window.h, ['Respond by pressing left for weaker \n \n' ...
                    ' and right for stronger motion in the second interval. \n \n' ...
                    ' \n \n\n \n\n \n Good luck!'],  'center', 'center');
            end
        case 1
            
            if setup.inGerman,
                DrawFormattedText(window.h, ['Drücken Sie rechts für eine schwächere \n \n' ...
                    '  und links für eine stärkere Bewegung im zweiten Interval. \n \n' ...
                    '  \n \n\n \n\n \n Viel Erfolg!'],  'center', 'center');
            else
                DrawFormattedText(window.h, ['Respond by pressing right for weaker \n \n' ...
                    ' and left for stronger motion in the second interval. \n \n' ...
                    '\n \n\n \n\n \n Good luck!'],  'center', 'center');
            end
    end
    Screen('Flip', window.h);
    WaitSecs(.1);
    CedrusResponseBox('WaitButtonPress', setup.responsebox);
    WaitSecs(.1);
end

%% Start looping through the blocks trials
for block = 1:setup.nblocks,
    
    DrawFormattedText(window.h, 'Loading...',  'center', 'center');
    Screen('Flip', window.h);
    
    % preload all the dot coordinates - overwrite this block!
    coord.ref           = nan(1, setup.ntrials, setup.nframes, 2, dots.nDots);
    coord.stim          = nan(1, setup.ntrials, setup.nframes, 2, dots.nDots);
    
    for trial = 1:setup.ntrials,
        % preload all the dot coordinates before starting the block
        coord.ref(1, trial, :, :, :)        = dots_refstim(setup, window, dots, block, trial);
        coord.stim(1, trial, :, :, :)       = dots_limitedlifetime(setup, window, dots, block, trial);
    end
    
    % save all the dot coordinates
    save(sprintf('Data/Dots_P%d_threshold_b%d_%s.mat', setup.participant, block, datestr(now, 'yyyy-mm-dd_HH-MM-SS')), '-mat', '-v7.3');
    
    Screen('FillRect', window.h, [0 0 0]);
    DrawFormattedText(window.h, ['Ready? Press a button to begin.'],  'center', 'center');
    Screen('Flip', window.h);
    CedrusResponseBox('WaitButtonPress', setup.responsebox);
    
    %% start the loop over trials
    for trial = 1:setup.ntrials,
        
        CedrusResponseBox('FlushEvents', setup.responsebox);
        
        if trial == 1, % draw new dots, otherwise keep the ones from the last trial
            window      = dots_noise_draw(window, dots);
            window      = drawFixation(window, fix, dots); %fixation
            breaktime   = Screen('Flip', window.h); % flip once, so stationary dots
        end
        % during thresholding, no blinkbreak
        WaitSecs(setup.ISI);
        
        % stimulus sequence onset
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
        keyIsDown = false; evt = [];
        WronglyPressed = false;
        CedrusResponseBox('FlushEvents', setup.responsebox);
        
        for frameNum = 1:setup.nframes,
            window      = drawAllDots(window, dots, 1, trial, coord.stim, frameNum);
            window      = drawFixation(window, fix, dots);
            
            [flip.stim.VBL(block, trial, frameNum), ...
                flip.stim.StimOns(block, trial, frameNum), ...
                flip.stim.FlipTS(block, trial, frameNum), ...
                flip.stim.Missed(block, trial, frameNum), ...
                flip.stim.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
            
            % check that they dont press too early
            evt = CedrusResponseBox('GetButtons', setup.responsebox);
            
            if frameNum == 1,
                % triggers
                if setup.MEG, outp(trigger.address, trigger.stim(block, trial)); WaitSecs(trigger.width); outp(trigger.address, trigger.zero);  end
            end
        end
        
        if ~isempty(evt),
            WronglyPressed = true;
        end
        
        if ~WronglyPressed,
            
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
            
            % no pupilrebound in thresholding
            if 0,
                % WAIT FOR THE PUPIL TO RETURN TO BASELINE
                keyIsDown = false; evt = [];
                WronglyPressed = false;
                CedrusResponseBox('FlushEvents', setup.responsebox);
                
                frameNum = 1;
                while GetSecs < setup.pupilreboundtime(block, trial)+ results.resptime(block, trial);
                    
                    window   = dots_noise_draw(window, dots);
                    window      = drawFixation(window, fix, dots); % fixation
                    
                    [flip.pupilrebound1.VBL(block, trial, frameNum), ...
                        flip.pupilrebound1.StimOns(block, trial, frameNum), ...
                        flip.pupilrebound1.FlipTS(block, trial, frameNum), ...
                        flip.pupilrebound1.Missed(block, trial, frameNum), ...
                        flip.pupilrebound1.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
                    frameNum = frameNum + 1;
                    
                    % check that they dont press anymore during the pupilrebound
                    evt = CedrusResponseBox('GetButtons', setup.responsebox);
                end
                if ~isempty(evt),
                    results.correct(block, trial) = NaN;
                end
            end
            
        else
            results.correct(block, trial) = NaN;
        end
        
        %% NO FEEDBACK
        if 0,
            if results.correct(block,trial) == true, %correct
                PsychPortAudio('SetLoop',audio.h, sound.tonepos(2,1), sound.tonepos(2,2));
            elseif results.correct(block,trial) == false, %incorrect
                PsychPortAudio('SetLoop',audio.h, sound.tonepos(3,1), sound.tonepos(3,2));
            elseif isnan(results.correct(block,trial)), % too early, wrong or too late response given
                PsychPortAudio('SetLoop',audio.h, sound.tonepos(4,1), sound.tonepos(4,2));
            else % unrecognized response
                setup.cancel = true;
                warning('could not determine which feedback to give');
            end
            results.feedbackonset(block, trial) = GetSecs;
            results.soundstart.feedback(block, trial) = PsychPortAudio('Start', audio.h);
        end
        
        % break out of all trials if ESC was pressed
        if setup.cancel,
            break
            warning('experiment was manually terminated');
        end
        
    end %end trial loop
    
    if block < setup.nblocks,
        if setup.inGerman,
            DrawFormattedText(window.h, sprintf('Fertig mit Block %d! \n \n Sie haben %.2f Prozent an Versuchsdurchgängen richtig beantwortet \n \n und Ihre mittlere Reaktionszeit war %.2f Sekunden. \n \n\n \n Drücken Sie eine beliebige Taste um fortzufahren.', ...
                block, nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:))), 'center', 'center');
        else
            DrawFormattedText(window.h, sprintf('Finished block %d! \n \n You answered %.2f percent of trials correct, \n \n and your average reaction time was %.2f seconds. \n \n\n \n Press any key to continue.', ...
                block, nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:))), 'center', 'center');
        end
    else % finish
        if setup.inGerman,
            DrawFormattedText(window.h, sprintf('Fertig mit Block %d! \n \n Sie haben %.2f Prozent an Versuchsdurchgängen richtig beantwortet \n \n und Ihre mittlere Reaktionszeit war %.2f Sekunden. \n \n\n \n Fertig! Bitte rufen Sie den Versuchsleiter.', ...
                block, nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:))), 'center', 'center');
        else
            DrawFormattedText(window.h, sprintf('Finished block %d! \n \n You answered %.2f percent of trials correct, \n \n and your average reaction time was %.2f seconds. \n \n\n \n Done! Please call the experimenter.', ...
                block, nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:))), 'center', 'center');
        end
    end
    Screen('Flip', window.h);
    
    % display accuracy over this block, per difficulty level
    fprintf('Correct per difficulty level: %.0f, %.0f, %.0f, %.0f, %.0f \n', ...
        100* nanmean(results.correct(block, abs(setup.coherence(block, :)-setup.cohlevels(1)) < 0.0001)), ...
        100* nanmean(results.correct(block, abs(setup.coherence(block, :)-setup.cohlevels(2)) < 0.0001)), ...
        100* nanmean(results.correct(block, abs(setup.coherence(block, :)-setup.cohlevels(3)) < 0.0001)), ...
        100* nanmean(results.correct(block, abs(setup.coherence(block, :)-setup.cohlevels(4)) < 0.0001)), ...
        100* nanmean(results.correct(block, abs(setup.coherence(block, :)-setup.cohlevels(5)) < 0.0001)));
    
    % break out of all blocks if ESC was pressed
    if setup.cancel == true,
        break
        warning('experiment was manually terminated');
    end
    
end %end block loop

% wrap up and save
setup.datetime = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
% create subject specific file and save - add unique datestring to avoid any overwriting of files
setup.filename = sprintf('Data/P%d_threshold_%s.mat', setup.participant, setup.datetime);
save(setup.filename, '-mat', 'setup', 'window', 'dots', 'fix', 'results', 'audio',  'sound', 'flip', 'trigger');
disp('SAVED FILE TO DISK'); disp(setup.filename);

% exit gracefully
disp('done!'); Screen('CloseAll'); ShowCursor;
PsychPortAudio('Stop', audio.h);
sca;

% take all results and plot the full psychometric extravaganza
[datapoints1, datapoints2, datapoints3, fit1, fit2, fit3] = FitThreshold_2IFC(setup.filename, 'fit', 'nobootstrap');
save(sprintf('Data/P%d_threshold.mat', setup.participant), 'fit1', 'fit2', 'fit3', 'datapoints1', 'datapoints3');
