%% 2-interval forced coice random dots
% example with very easy motion strength before subjects start thresholding
%
% Edited: Anne Urai, 26 May 2015
% -----------------------------------------------------------------

clear all; close all; clc;
cd C:\Users\eeg-lab\Desktop\AnneUrai\2IFC_RDK_UKE;
addpath(genpath(pwd));

path_ptb = fullfile('C:\Users\eeg-lab\Desktop\TACSATT\Hannah\myPTB');
addpath(genpath(path_ptb));

% general setup
setup.Eye           = false; % true if using Eyelink (will use pupil rebound time as well)
setup.MEG           = false; % true if sending triggers to the MEG
setup.cancel        = false; % becomes true if escape is pressed, will abort experiment (but save data)
setup.thresholding  = false;

% ask for subject number, default: 0
setup.participant       = input('Participant number? ');
if isempty(setup.participant), setup.participant = 0; end

setup.inGerman          = input('Instructions in German? ');
if isempty(setup.inGerman), setup.inGerman = 1; end % English = default

setup.Instructions      = input('Show instructions? ');
if isempty(setup.Instructions), setup.Instructions = 1; end

%% Setup the PsychToolbox
window.dist             = 60; % viewing distance in cm , 60 in EEG lab
window.width            = 53.5; % physical width of the screen in cm, 53.5 for BENQ in EEG lab
window.height           = 30; % physical height of the screen in cm, 42 for the MEG projector screen inside the scanner
window.skipChecks       = 1; % set to 1 to skip VBL tests and avoid warnings
[window, audio]         = SetupPTB(window); %load all the psychtoolbox things
if setup.MEG,           window.cogent = cogent;  end %save information about the io details
if setup.Eye,           el = ELconfig(window); end

%% CONFIGURATION

[setup, dots, fix, results, sound, flip, coord, trigger] = configuration_2IFC_example(window, audio, setup);

% make Kb Queue
CedrusResponseBox('CloseAll');
IOPort('CloseAll');
setup.responsebox = CedrusResponseBox('Open', 'COM9');
evt = [];

Screen('TextSize', window.h, 20);
Screen('TextFont', window.h, 'Trebuchet');
Screen('TextColor', window.h, [255 255 255] );

if setup.Instructions,
    if setup.inGerman,
        DrawFormattedText(window.h, ['Jetzt wo Sie wissen wie die starke und schwache Bewegung aussieht,  \n \n' ...
            ' werden Sie die Bewegungsstärke in zwei aufeinanderfolgenden Intervallen vergleichen.  \n \n' ...
            ' In jedem Durchgang werden Sie den Ton zweimal hören, und die Punkte werden sich zweimal bewegen.  \n \n\n\n' ...
            ' Ihre Aufgabe ist es, zu entscheiden ob das zweite Intervall \n \n' ...
            ' eine STÄRKERE oder SCHWÄCHERE Bewegung als das erste hatte. '],  'center', 'center');
    else
        DrawFormattedText(window.h, ['Now that you know what strong and weak motion looks like,  \n \n' ...
            ' you will compare motion strength in two successive intervals.  \n \n' ...
            ' Every trial, you will hear the beep twice, and see the dots moving twice.  \n \n\n\n' ...
            ' It is your task to decide if the second interval \n \n' ...
            ' had STRONGER or WEAKER motion than the first. '],  'center', 'center');
    end
    Screen('Flip', window.h);
    CedrusResponseBox('WaitButtonPress', setup.responsebox);
    
    switch mod(setup.participant, 2);
        case 0
            if setup.inGerman,
                DrawFormattedText(window.h, ['Nachdem das zweite Interval zu Ende ist,\n \n' ...
                    ' drücken Sie LINKS für eine SCHWÄCHERE \n \n' ...
                    ' und RECHTS für eine STÄRKERE Bewegung in dem zweiten Intervall. \n \n\n\n' ...
                    ' Benutzen Sie Ihre linke und Ihre rechte Hand, um die Tasten zu drücken  \n \n' ...
                    ' und sitzen Sie aufrecht vor der Mitte Ihres Bildschirms. \n \n\n\n' ...
                    ' In diesem Beispiel werden Sie feedback auf Ihre Antwort \n \n' ...
                    ' in Form eines Tons und eines Textes auf dem Bildschirm erhalten. \n \n'],  'center', 'center');
            else
                DrawFormattedText(window.h, ['After the second interval has finished,\n \n' ...
                    ' you can respond by pressing LEFT for WEAKER \n \n' ...
                    ' and RIGHT for STRONGER motion in the second interval. \n \n\n\n' ...
                    ' Use your left and right hand to press the buttons, \n \n' ...
                    ' and sit straight in front of middle of the screen. \n \n\n\n' ...
                    ' In this example, you will receive feedback on your response \n \n' ...
                    ' in the form of a sound, and a written feedback on the screen. \n \n'],  'center', 'center');
            end
        case 1
            if setup.inGerman,
                DrawFormattedText(window.h, ['Nachdem das zweite Interval zu Ende ist,\n \n' ...
                    ' drücken Sie RECHTS für eine SCHWÄCHERE \n \n' ...
                    ' und LINKS für eine STÄRKERE Bewegung in dem zweiten Intervall. \n \n\n\n' ...
                    ' Benutzen Sie Ihre linke und Ihre rechte Hand, um die Tasten zu drücken , \n \n' ...
                    ' und sitzen Sie aufrecht vor der Mitte Ihres Bildschirms. \n \n\n\n' ...
                    ' In diesem Beispiel werden Sie feedback auf Ihre Antwort \n \n' ...
                    ' in Form eines Tons und eines Textes auf dem Bildschirm erhalten. \n \n'],  'center', 'center');
            else
                DrawFormattedText(window.h, ['After the second interval has finished,\n \n' ...
                    ' you can respond by pressing RIGHT for WEAKER \n \n' ...
                    ' and LEFT for STRONGER motion in the second interval. \n \n\n\n' ...
                    ' Use your left and right hand to press the buttons, \n \n' ...
                    ' and sit straight in front of middle of the screen. \n \n\n\n' ...
                    ' In this example, you will receive feedback on your response \n \n' ...
                    ' in the form of a sound, and a written feedback on the screen. \n \n'],  'center', 'center');
            end
    end
    Screen('Flip', window.h);
    WaitSecs(.1);
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
                                '  und einen tiefen Ton für falsche Antworten. \n \n\n \n\n \n Viel Erfolg!'],  'center', 'center');
                        else
                            DrawFormattedText(window.h, ['Respond by pressing left for weaker \n \n' ...
                                ' and right for stronger motion in the second interval. \n \n' ...
                                ' You will hear a high beep for correct responses, \n \n' ...
                                ' and a low beep for errors. \n \n\n \n\n \n Good luck!'],  'center', 'center');
                        end
                    case 2
                        if setup.inGerman,
                            DrawFormattedText(window.h, ['Drücken Sie links für eine schwächere \n \n' ...
                                '  und rechts für eine stärkere Bewegung im zweiten Interval. \n \n' ...
                                '  Sie werden einen tiefen Ton für richtige Anworten hören, \n \n' ...
                                '  und einen hohen Ton für falsche Antworten. \n \n\n \n\n \n Viel Erfolg!'],  'center', 'center');
                        else
                            DrawFormattedText(window.h, ['Respond by pressing left for weaker \n \n' ...
                                ' and right for stronger motion in the second interval. \n \n' ...
                                ' You will hear a low beep for correct responses, \n \n' ...
                                ' and a high beep for errors. \n \n\n \n\n \n Good luck!'],  'center', 'center');
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
end

%% Start looping through the blocks trials
for block = 1:setup.nblocks,
    
    if setup.MEG,
        % show the head localization screen to the subject
        vswitch(02);
        keyIsDown = false; while ~keyIsDown, keyIsDown = PsychHID('KbQueueCheck'); end
        % show the normal stim screen again
        vswitch(00);
    end
    
    if setup.Eye == true,
        %  open edf file for recording data from Eyelink - CANNOT BE MORE THAN 8 CHARACTERS
        edfFile = sprintf('%ds%db%d.edf', setup.participant, setup.session, block);
        Eyelink('Openfile', edfFile);
        
        % send information that is written in the preamble
        preamble_txt = sprintf('%s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %d', ...
            'Experiment', '2IFC RandomDots', ...
            'subjectnr', setup.participant, ...
            'edfname', edfFile, ...
            'screen_hz', window.frameRate, ...
            'screen_resolution', window.rect, ...
            'date', datestr(now),...
            'screen_distance', window.dist);
        Eyelink('command', 'add_file_preamble_text ''%s''', preamble_txt);
        
        % Calibrate the eye tracker
        EyelinkDoTrackerSetup(el);
        % drift correction
        EyelinkDoDriftCorrection(el);
        
        % start recording eye position
        Eyelink('StartRecording');
        % record a few samples before we actually start displaying
        WaitSecs(0.1);
        % mark zero-plot time in data file
        Eyelink('message', 'Start recording Eyelink');
        
    end
    
    %% start the loop over trials
    for trial = 1:setup.ntrials,
        
        if setup.Eye,
            Eyelink ('Message', 'blinkbreak_start');
        end
        
        window      = drawAllDots(window, dots, block, trial, coord.fix, 1);
        window      = drawFixation(window, fix, dots); %fixation
        Screen('Flip', window.h); % flip once, so stationary dots
        WaitSecs(1);
        
        if setup.Eye,
            Eyelink ('Message', 'blinkbreak_end');
        end
        
        %% stimulus sequence onset
        % FIXATION
        if setup.Eye, Eyelink ('Message', sprintf('block%d_trial%d_fix', block, trial));
            Eyelink('command', 'record_status_message ''Trial %d''', trial);    end
        
        for frameNum = 1:ceil(setup.fixtime(block, trial)*window.frameRate),
            
            window      = drawAllDots(window, dots, block, trial, coord.fix, frameNum);
            window      = drawFixation(window, fix, dots); % fixation
            
            [flip.fix.VBL(block, trial, frameNum), ...
                flip.fix.StimOns(block, trial, frameNum), ...
                flip.fix.FlipTS(block, trial, frameNum), ...
                flip.fix.Missed(block, trial, frameNum), ...
                flip.fix.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
            
            if frameNum == 1,
                if setup.MEG, outp(trigger.address, trigger.fix); WaitSecs(trigger.width); outp(trigger.address, trigger.zero);  end
            end
        end
        
        if setup.Eye, Eyelink ('Message', sprintf('block%d_trial%d_ref', block, trial)); end
        
        % play reference stimulus onset tone
        PsychPortAudio('SetLoop',audio.h, sound.tonepos(1,1), sound.tonepos(1,2));
        results.soundstart.ref(block, trial) = PsychPortAudio('Start', audio.h); %like flip
        
        % REFERECE STIMULUS with 70% coherence
        for frameNum = 1:setup.nframes,
            
            window      = drawAllDots(window, dots, block, trial, coord.ref, frameNum);
            window      = drawFixation(window, fix, dots); % fixation
            
            [flip.refstim.VBL(block, trial, frameNum), ...
                flip.refstim.StimOns(block, trial, frameNum), ...
                flip.refstim.FlipTS(block, trial, frameNum), ...
                flip.refstim.Missed(block, trial, frameNum), ...
                flip.refstim.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
            
            if frameNum == 1,
                % triggers
                if setup.MEG, outp(trigger.address, trigger.ref); WaitSecs(trigger.width); outp(trigger.address, trigger.zero);  end
            end
        end
        
        if setup.Eye, Eyelink ('Message', sprintf('block%d_trial%d_interval', block, trial)); end
        
        % INTERVAL
        for frameNum = 1:ceil(setup.intervaltime(block, trial)*window.frameRate),
            
            window      = drawAllDots(window, dots, block, trial, coord.interval, frameNum);
            window      = drawFixation(window, fix, dots); % fixation
            
            [flip.interval.VBL(block, trial, frameNum), ...
                flip.interval.StimOns(block, trial, frameNum), ...
                flip.interval.FlipTS(block, trial, frameNum), ...
                flip.interval.Missed(block, trial, frameNum), ...
                flip.interval.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
            
            if frameNum == 1,
                % triggers
                if setup.MEG, outp(trigger.address, trigger.interval); WaitSecs(trigger.width); outp(trigger.address, trigger.zero);  end
            end
        end
        
        if setup.Eye, Eyelink ('Message', sprintf('block%d_trial%d_stim_inc%d', block, trial, setup.increment)); end
        
        % play test stimulus onset tone
        PsychPortAudio('SetLoop',audio.h, sound.tonepos(1,1), sound.tonepos(1,2));
        results.soundstart.stim(block, trial) = PsychPortAudio('Start', audio.h); %like flip
        
        % TEST STIMULUS
        keyIsDown = false; evt = [];
        WronglyPressed = false;
        CedrusResponseBox('FlushEvents', setup.responsebox);
        
        for frameNum = 1:setup.nframes,
            window      = drawAllDots(window, dots, block, trial, coord.stim, frameNum);
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
                
                window      = drawAllDots(window, dots, block, trial, coord.resp, frameNum);
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
            
            disp(evt);
            
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
            
            % trigger
            switch results.response(block, trial),
                case -1 % weaker
                    if setup.MEG, outp(trigger.address, trigger.resp.weaker); WaitSecs(trigger.width); outp(trigger.address, trigger.zero);  end
                case 1 % stronger
                    if setup.MEG, outp(trigger.address, trigger.resp.stronger); WaitSecs(trigger.width); outp(trigger.address, trigger.zero);  end
                otherwise %send a different trigger for no response
                    if setup.MEG, outp(trigger.address, trigger.resp.noresp); WaitSecs(trigger.width); outp(trigger.address, trigger.zero);  end
            end
            
            % code for correct responses
            if results.response(block, trial) == setup.increment(block,trial), %whether motion is stronger than 50% or not
                results.correct(block,trial) = true;
            elseif isnan(results.response(block, trial)),
                results.correct(block,trial) = NaN;
                results.RT(block,trial) = NaN; %set RT to NaN to easily filter out trials without a response
            else results.correct(block,trial) = false;
            end
            
            % send all information in one trigger to EyeLink
            if setup.Eye, Eyelink ('Message', sprintf('block%d_trial%d_resp_key%d_correct%d', block, trial, results.response(block, trial), results.correct(block, trial))); end
            
            % another trigger with the info whether the resp was correct
            switch results.correct(block, trial),
                case 0 % wrong
                    if setup.MEG, outp(trigger.address, trigger.resp.incorrect); WaitSecs(trigger.width); outp(trigger.address, trigger.zero);  end
                case 1 % stronger
                    if setup.MEG, outp(trigger.address, trigger.resp.incorrect); WaitSecs(trigger.width); outp(trigger.address, trigger.zero);  end
            end
            
            % WAIT FOR THE PUPIL TO RETURN TO BASELINE
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
            end
            
        else
            results.correct(block, trial) = NaN;
        end
        
        %% FEEDBACK
        
        if results.correct(block,trial) == true, %correct
            PsychPortAudio('SetLoop',audio.h, sound.tonepos(2,1), sound.tonepos(2,2));
        elseif results.correct(block,trial) == false, %incorrect
            PsychPortAudio('SetLoop',audio.h, sound.tonepos(3,1), sound.tonepos(3,2));
        elseif isnan(results.correct(block,trial)), % no response given
            PsychPortAudio('SetLoop',audio.h, sound.tonepos(4,1), sound.tonepos(4,2));
        else %unrecognized response
            setup.cancel = true;
            warning('could not determine which feedback to give');
        end
        results.feedbackonset(block, trial) = GetSecs;
        
        if setup.Eye, Eyelink ('Message', sprintf('block%d_trial%d_feedback_correct%d_diff%d', block, trial, results.correct(block, trial), find(setup.difficulty(block, trial)==setup.cohlevels))); end
        results.soundstart.feedback(block, trial) = PsychPortAudio('Start', audio.h);
        
        % feedback trigger
        switch results.correct(block, trial),
            case 0 % wrong
                if setup.MEG, outp(trigger.address, trigger.feedback.incorrect); WaitSecs(trigger.width); outp(trigger.address, trigger.zero);  end
            case 1 % correct
                if setup.MEG, outp(trigger.address, trigger.feedback.incorrect); WaitSecs(trigger.width); outp(trigger.address, trigger.zero);  end
        end
        
        % wait for the pupil to return to baseline, average 3s
        
        frameNum = 1;
        while GetSecs < setup.pupilreboundtime2(block, trial)+ results.feedbackonset(block, trial);
            
            window      = dots_noise_draw(window, dots);
            window      = drawFixation(window, fix, dots); % fixation
            
            if results.correct(block,trial) == true, %correct
                Screen('DrawText', window.h, 'CORRECT', window.center(1)*0.95, window.center(2) , [255 255 255] );
            elseif results.correct(block,trial) == false, %incorrect
                Screen('DrawText', window.h, 'ERROR', window.center(1)*0.95, window.center(2) , [255 255 255] );
            elseif isnan(results.correct(block,trial)), %no response given
                Screen('DrawText', window.h, 'NO RESPONSE', window.center(1)*0.95, window.center(2) , [255 255 255] );
            end
            
            [flip.pupilrebound2.VBL(block, trial, frameNum), ...
                flip.pupilrebound2.StimOns(block, trial, frameNum), ...
                flip.pupilrebound2.FlipTS(block, trial, frameNum), ...
                flip.pupilrebound2.Missed(block, trial, frameNum), ...
                flip.pupilrebound2.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
            frameNum = frameNum + 1;
        end
        
        % break out of all trials if ESC was pressed
        if setup.cancel,
            break
            warning('experiment was manually terminated');
        end
        
        if setup.Instructions,
            if trial == 1,
                if setup.inGerman,
                    DrawFormattedText(window.h, ['Bitte beachten Sie Folgendes: \n \n \n \n \n \n ' ...
                        '1. \n \n Beide Stimuli dauern gleich lang \n \n' ...
                        ' und es gibt eine Zeitraum mit zufälligem Flackern dazwischen. \n \n' ...
                        ' Dieser Zeitraum enthält keine wichtigen Informationen für die Aufgabe,\n \n' ...
                        ' er stellt lediglich eine kurze Pause zwischen den beiden Stimuli dar.'],  'center', 'center');
                else
                    DrawFormattedText(window.h, ['The following things are important to keep in mind: \n \n \n \n \n \n ' ...
                        '1. \n \n Both stimuli last for the same amount of time, \n \n' ...
                        ' and there is period of random flicker in between them. \n \n' ...
                        ' This period does not contain information that is useful for the task,\n \n' ...
                        ' but is just a short break in between the two stimuli.'],  'center', 'center');
                end
                
                Screen('Flip', window.h);
                WaitSecs(1);
                CedrusResponseBox('WaitButtonPress', setup.responsebox);
                if setup.inGerman,
                    DrawFormattedText(window.h, ['2. \n \n Die Aufgabe ist am leichtesten wenn Sie auf den roten Punkt schauen, \n \n' ...
                        ' und nicht versuchen, einzelne Punkte mit den Augen zu verfolgen. \n \n' ...
                        ' Am besten ist es, die gesamte visuelle Information in der Punktwolke zu integrieren. '],  'center', 'center');
                    
                else
                    DrawFormattedText(window.h, ['2. \n \n The task is easiest when you look at the red point, \n \n' ...
                        ' and do not try to follow individual dots with your eyes. \n \n' ...
                        ' The best is to integrate all the visual information in the cloud of dots. '],  'center', 'center');
                end
                Screen('Flip', window.h);
                WaitSecs(1);
                CedrusResponseBox('WaitButtonPress', setup.responsebox);
                
                if setup.inGerman,
                    DrawFormattedText(window.h, ['3.\n \n Antworten Sie erst nachdem der zweite Stimulus zu Ende ist, \n \n' ...
                        ' warten Sie also bis die Bewegung gestoppt hat \n \n' ...
                        ' und verwenden Sie die gesamte Information der Bewegung.\n \n' ...
                        ' Ab dem Moment an dem der zweite Stimulus gestoppt hat \n \n' ...
                        ' haben Sie 3 Sekunden, um zu antworten.  \n \n' ...
                        ' Wenn Sie die Taste zu früh oder zu spät drücken \n \n' ...
                        ' wird die Antwort als Fehler gewertet. '],  'center', 'center');
                else
                    DrawFormattedText(window.h, ['3.\n \n You can only respond after the second stimulus has finished, \n \n' ...
                        ' so wait until it stopped moving and use all the information in it.\n \n' ...
                        ' From the moment the second stimulus stopped, \n \n' ...
                        ' you have 3 seconds to give your response.  \n \n' ...
                        ' If you press the button too early or too late, \n \n' ...
                        ' the response will be counted as an error. '],  'center', 'center');
                end
                Screen('Flip', window.h);
                WaitSecs(1);
                
                CedrusResponseBox('WaitButtonPress', setup.responsebox);
                if setup.inGerman,
                    DrawFormattedText(window.h, ['4. \n \n Hören Sie gut auf die Feedbacktöne: \n \n' ...
                        ' Während des richtigen Experiments werden Sie kein visuelles Feedback bekommen, \n \n' ...
                        ' es ist also wichtig, dass Sie sich merken welcher Ton eine richtige und welcher eine falsche Antwort signalisiert.'],  'center', 'center');
                else
                    
                    DrawFormattedText(window.h, ['4. \n \n Listen closely to the feedback sounds: \n \n' ...
                        ' during the real experiment you will not receive visual feedback, \n \n' ...
                        ' so it is important that you remember which sound indicates correct and error.'],  'center', 'center');
                end
                
                Screen('Flip', window.h);
                WaitSecs(1);
                CedrusResponseBox('WaitButtonPress', setup.responsebox);
                
            elseif trial == 3,
                Screen('FillRect', window.h, window.black);
                Screen('Flip', window.h); % flip once, so stationary dots
                
                if setup.inGerman,
                    DrawFormattedText(window.h, ['Wie Sie gesehen haben flackern die Punkte nach dem Feedback weiter. \n \n' ...
                        'Versuchen Sie, währenddessen Ihre Augen geöffnet zu halten. \n \n' ...
                        'Wenn die Punkte aufhören, sich zu bewegen haben Sie eine kurze Pause, um zu blinzeln\n \n', ...
                        'bevor Sie mit dem nächsten Durchgang weitermachen.'],  'center', 'center');
                else
                    DrawFormattedText(window.h, ['As you have seen, the dots continue to flicker after the feedback. \n \n' ...
                        'Try to keep your eyes open during this time. \n \n' ...
                        'When the dots stop moving, you have a short break to blink your eyes \n \n', ...
                        'before you continue to the next trial.'],  'center', 'center');
                end
                
                Screen('Flip', window.h);
                WaitSecs(1);
                CedrusResponseBox('WaitButtonPress', setup.responsebox);
            end
        end
        
    end %end trial loop
    
    if block < setup.nblocks,
        if setup.inGerman,
            DrawFormattedText(window.h, sprintf('Fertig! \n \n Sie haben %.2f Prozent an Versuchsdurchgängen richtig beantwortet, \n \n und Ihre mittlere Reaktionszeit war %.2f Sekunden. \n \n\n \n Drücken Sie eine beliebige Taste, um weiterzumachen.', ...
                nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:))), 'center', 'center');
        else
            DrawFormattedText(window.h, sprintf('Finished! \n \n You answered %.2f percent of trials correct, \n \n and your average reaction time was %.2f seconds. \n \n\n \n Press any key to continue.', ...
                nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:))), 'center', 'center');
        end
        
    else % finish
        if setup.inGerman,
            DrawFormattedText(window.h, sprintf( 'Fertig! \n \n Sie haben %.2f Prozent an Versuchsdurchgängen richtig beantwortet, \n \n und Ihre mittlere Reaktionszeit war %.2f Sekunden. \n \n\n \n Fertig! Bitte rufen Sie den Versuchsleiter.', ...
                nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:))), 'center', 'center');
        else
            DrawFormattedText(window.h, sprintf('Finished! \n \n You answered %.2f percent of trials correct, \n \n and your average reaction time was %.2f seconds. \n \n\n \n Done! Please call the experimenter.', ...
                nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:))), 'center', 'center');
        end
    end
    Screen('Flip', window.h);
    CedrusResponseBox('WaitButtonPress', setup.responsebox);
    
    fprintf( 'Fertig! \n \n Sie haben %.2f Prozent an Versuchsdurchgängen richtig beantwortet, \n \n und Ihre mittlere Reaktionszeit war %.2f Sekunden. \n \n\n \n Fertig! Bitte rufen Sie den Versuchsleiter.', ...
                nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:)));
    %% save the EL file for this block
    if setup.Eye == true,
        
        setup.datetime      = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
        setup.eyefilename   = sprintf('Data/MEG_P%d_s%d_b%d_%s.edf', setup.participant, setup.session, block, setup.datetime);
        Eyelink('CloseFile');
        Eyelink('WaitForModeReady', 500);
        try
            status              = Eyelink('ReceiveFile',edfFile, setup.eyefilename); %this collects the file from the eyelink
            disp(['File ' setup.eyefilename ' saved to disk']);
        catch
            warning(['File ' setup.eyefilename ' not saved to disk']);
        end
    end
    
    % break out of all blocks if ESC was pressed
    if setup.cancel == true,
        break
        warning('experiment was manually terminated');
    end
    
     % wait a few seconds before exiting
    WaitSecs(2);
    
end %end block loop

% close the eyelink
if setup.Eye == true,
    Eyelink('StopRecording');
end

% exit gracefully
disp('done!'); Screen('CloseAll'); ShowCursor;
PsychPortAudio('Stop', audio.h);
sca;
