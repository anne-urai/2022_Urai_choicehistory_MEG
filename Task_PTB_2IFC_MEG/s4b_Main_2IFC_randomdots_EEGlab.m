%% 2-interval forced coice random dots
%
% order of events for timing:
% 1. send EyeLink message (least important that the timing is perfect
% 2. start Audio playback (because this takes some time to start playing,
% and will include 10ms of burst before the actual tone starts (can be detected as an alternative trig)
% 3. start flip loop
% 4. at framenum == 1, send parport trigger
%
% see MEGtimingTests for a rough idea of how accurately the parport
% triggers, audio burst and flips are sent over to the MEG
%
% Anne Urai, UKE, April 2014
%
% -----------------------------------------------------------------

clear all; close all; clc;
try
    cd E:\Users\Urai\Desktop\2IFC_RDK;c
end
addpath(genpath(pwd));

% add psychtoolbox path - not automatic in the EEG lab
path_ptb = fullfile('C:','Documents and Settings','meg','Desktop', 'Experimente','Hannah','myPTB');
addpath(genpath(path_ptb));

% general setup
setup.Eye           = false; % true if using Eyelink
setup.MEG           = false; % true if sending triggers to the MEG
setup.cancel        = false; % becomes true if escape is pressed, will abort experiment (but save data)
setup.training      = true; % will increase the nr of trials, no pupil rebound, and save under different filename
% use setup.training in the EEG lab for psychophysics

% ask for subject number, default: 0
setup.participant       = input('Participant number? ');
if isempty(setup.participant), setup.participant = 0; end %test

% ask for session number, default: 0
setup.session           = input('Session? 1-5 '); % MEG, 2x training, MEG
if isempty(setup.session), setup.session = 0; end %test

% load in individual threshold
try
    load(sprintf('Data/P%d_threshold.mat', setup.participant));
    setup.threshold           = seventypercentthreshold; %take the coherence level that leads to 65% correct
catch
    setup.threshold           = input('This participant''s threshold? 0-1 ');
    
    % save this input for future blocks
    seventypercentthreshold = setup.threshold;
    savefast(sprintf('Data/P%d_threshold.mat', setup.participant), 'seventypercentthreshold');
end


%% Setup the PsychToolbox
window.dist             = 60; % viewing distance in cm , 60 in EEG lab
window.width            = 53.5; % physical width of the screen in cm, 53.5 for BENQ in EEG lab
window.height           = 30; % physical height of the screen in cm, 42 for the MEG projector screen inside the scanner
window.skipChecks       = 1; % set to 1 to skip VBL tests and avoid warnings
[window, audio]         = SetupPTB_EEGlab(window); %load all the psychtoolbox things
if setup.MEG,           window.cogent = cogent;  end %save information about the io details
if setup.Eye,           el = ELconfig(window); end

Screen('TextSize', window.h, 20);
Screen('TextFont', window.h, 'Trebuchet');
Screen('TextColor', window.h, [255 255 255] );

% main config
[setup, dots, fix, results, sound, flip, trigger] = configuration(window, audio, setup);



for block = 1:setup.nblocks,
    
    DrawFormattedText(window.h, 'Loading...',  'center', 'center');
    Screen('Flip', window.h);
    
    % block-specific config
    tic
    coord = struct;
    % preload all the dot coordinates
    coord.fix           = nan(1, setup.ntrials, ceil(max(setup.fixtime(:))*window.frameRate), 2, dots.nDots);
    coord.ref           = nan(1, setup.ntrials, setup.nframes, 2, dots.nDots);
    coord.interval      = nan(1, setup.ntrials, ceil(max(setup.intervaltime(:))*window.frameRate), 2, dots.nDots);
    coord.stim          = nan(1, setup.ntrials, setup.nframes, 2, dots.nDots);
    coord.resp          = nan(1, setup.ntrials, ceil(max(setup.resptime(:))*window.frameRate), 2, dots.nDots);
    
    for trial = 1:setup.ntrials,
        
        % preload all the dot coordinates before starting the trial
        coord.fix(1, trial, :, :, :)        = dots_noise(dots, ceil(max(setup.fixtime(:))*window.frameRate));
        coord.ref(1, trial, :, :, :)        = dots_refstim(setup, window, dots, block, trial);
        coord.interval(1, trial, :, :, :)   = dots_noise(dots, ceil(max(setup.intervaltime(:))*window.frameRate));
        coord.stim(1, trial, :, :, :)       = dots_limitedlifetime(setup, window, dots, block, trial);
        coord.resp(1, trial, :, :, :)       = dots_noise(dots, ceil(max(setup.resptime(:))*window.frameRate));
        
    end
    
    % save this full config just to be sure
    savefast(sprintf('Data/Dots_P%d_s%d_b%d_%s.mat', setup.participant, setup.session, block, datestr(now, 'yyyy-mm-dd_HH-MM-SS')), 'coord');
    toc
    
    % still show the squares
    window      = drawFixation(window, fix, dots); %fixation
    Screen('Flip', window.h);
    
    %% Start looping through the blocks trials
     % display instructions
    if setup.participant > 0,
        switch mod(setup.participant, 2);
            case 0
                switch setup.feedbackcounterbalance(setup.participant),
                    case 1
                        DrawFormattedText(window.h, 'Respond by pressing left for weaker \n \n and right for stronger motion in the second interval. \n \n You will hear a high beep for correct responses, \n \n and a low beep for errors. \n \n\n \n\n \n Good luck!',  'center', 'center');
                    case 2
                        DrawFormattedText(window.h, 'Respond by pressing left for weaker \n \n and right for stronger motion in the second interval. \n \n You will hear a low beep for correct responses, \n \n and a high beep for errors. \n \n\n \n\n \n Good luck!',  'center', 'center');
                end
            case 1
                switch setup.feedbackcounterbalance
                    case 1
                        DrawFormattedText(window.h, 'Respond by pressing right for weaker \n \n and left for stronger motion in the second interval. \n \n You will hear a high beep for correct responses, \n \n and a low beep for errors. \n \n\n \n\n \n Good luck!',  'center', 'center');
                    case 2
                        DrawFormattedText(window.h, 'Respond by pressing right for weaker \n \n and left for stronger motion in the second interval. \n \n You will hear a low beep for correct responses, \n \n and a high beep for errors. \n \n\n \n\n \n Good luck!',  'center', 'center');
                end
        end
        Screen('Flip', window.h);
        WaitSecs(.1);
        CedrusResponseBox('WaitButtonPress', setup.responsebox);
        WaitSecs(.1);
    end
    
    %% start the loop over trials
    for trial = 1:setup.ntrials,
        
        if trial == 1, % draw new dots, otherwise keep the ones from the last trial
            window      = dots_noise_draw(window, dots);
            window      = drawFixation(window, fix, dots); %fixation
            Screen('Flip', window.h); % flip once, so stationary dots
        end
        WaitSecs(setup.ISI);
        % ISI of 1s - no blinkbreak for thresholding
        
        %% stimulus sequence onset
        % FIXATION
        for frameNum = 1:ceil(setup.fixtime(block, trial)*window.frameRate),
            
            window      = drawAllDots(window, dots, 1, trial, coord.fix, frameNum);
            window      = drawFixation(window, fix, dots); % fixation
            
            [flip.fix.VBL(block, trial, frameNum), ...
                flip.fix.StimOns(block, trial, frameNum), ...
                flip.fix.FlipTS(block, trial, frameNum), ...
                flip.fix.Missed(block, trial, frameNum), ...
                flip.fix.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
        end
        % play reference stimulus onset tone
        PsychPortAudio('SetLoop',audio.h, sound.tonepos(3,1), sound.tonepos(3,2));
        results.soundstart.ref(block, trial) = PsychPortAudio('Start', audio.h); %like flip
        
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
            
            window      = drawAllDots(window, dots, 1, trial, coord.interval, frameNum);
            window      = drawFixation(window, fix, dots); % fixation
            
            [flip.interval.VBL(block, trial, frameNum), ...
                flip.interval.StimOns(block, trial, frameNum), ...
                flip.interval.FlipTS(block, trial, frameNum), ...
                flip.interval.Missed(block, trial, frameNum), ...
                flip.interval.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
        end
        
        % play test stimulus onset tone
        PsychPortAudio('SetLoop',audio.h, sound.tonepos(3,1), sound.tonepos(3,2));
        results.soundstart.stim(block, trial) = PsychPortAudio('Start', audio.h); %like flip
        
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
            
            window      = drawAllDots(window, dots, 1, trial, coord.resp, frameNum);
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
                        case 'unknown'
                            setup.cancel = true;
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
                        case 'unknown'
                            setup.cancel = true;
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
        
        if ~setup.training,
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
        end
        
        %% FEEDBACK
        
        if results.correct(block,trial) == true, %correct
            PsychPortAudio('SetLoop',audio.h, sound.tonepos(1,1), sound.tonepos(1,2));
        elseif results.correct(block,trial) == false, %incorrect
            PsychPortAudio('SetLoop',audio.h, sound.tonepos(2,1), sound.tonepos(2,2));
        elseif isnan(results.correct(block,trial)), %no response given, extra long tone
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
                if setup.MEG, outp(trigger.address, trigger.feedback.correct); WaitSecs(trigger.width); outp(trigger.address, trigger.zero);  end
            otherwise %send a different trigger for no response
                if setup.MEG, outp(trigger.address, trigger.feedback.noresp); WaitSecs(trigger.width); outp(trigger.address, trigger.zero);  end
        end
        
        if ~setup.training,
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
        end
        
        % break out of all trials if ESC was pressed
        if setup.cancel,
            break
            warning('experiment was manually terminated');
        end
        
    end %end trial loop
    
     
    if block < setup.nblocks,
        DrawFormattedText(window.h, sprintf('Finished block %d! \n \n You answered %.2f percent of trials correct, \n \n and your average reaction time was %.2f seconds. \n \n\n \n Press any key to continue.', ...
            block, nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:))), 'center', 'center');
    else % finish
        DrawFormattedText(window.h, sprintf('Finished block %d! \n \n You answered %.2f percent of trials correct, \n \n and your average reaction time was %.2f seconds. \n \n\n \n Done! Please call the experimenter.', ...
            block, nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:))), 'center', 'center');
    end
    Screen('Flip', window.h);
    CedrusResponseBox('WaitButtonPress', setup.responsebox);
    
    % also show this info in the command window
    fprintf('Finished block %d! \n \n You answered %.2f percent of trials correct, \n \n and your average reaction time was %.2f seconds. \n \n\n \n Press any key to continue.', ...
        block, nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:)));
    
    %% save the EL file for this block
    if setup.Eye == true,
        
        setup.datetime      = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
        setup.eyefilename   = sprintf('Data/EL_P%d_s%d_b%d_%s.edf', setup.participant, setup.session, block, setup.datetime);
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
    
    evt = CedrusResponseBox('WaitButtonPress', setup.responsebox);
    
end

WaitSecs(.1);
% wait for keypress to start with the next block
evt = CedrusResponseBox('WaitButtonPress', setup.responsebox);

%% wrap up and save
setup.datetime = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
% create subject specific file and save - add unique datestring to avoid any overwriting of files
setup.filename = sprintf('Data/P%d_s%d_b%d_%s.mat', setup.participant, setup.session, block, setup.datetime);
save(setup.filename, '-mat', 'setup', 'window', 'dots', 'fix', 'results', 'audio',  'sound', 'flip', 'trigger');
disp('SAVED FILE TO DISK'); disp(setup.filename);
%% 

% close the eyelink
if setup.Eye== true,
    Eyelink('StopRecording');
end

% exit gracefully
disp('done!'); Screen('CloseAll'); ShowCursor;
PsychPortAudio('Stop', audio.h);
sca;

if setup.Eye,
    msgbox('DO NOT FORGET TO CONVERT EDF TO ASC!');
end


msgbox('DO NOT FORGET TO START AT BLOCK 1 AGAIN!');

% conduct timing test
setup.thresholding = false;
testmissedflips(window,flip, setup);
