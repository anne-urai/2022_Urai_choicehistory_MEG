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
% Updated May 2015, merged MEG and EEGlab scripts
%
% -----------------------------------------------------------------

clear all; close all; clc;

% general setup
setup.MEG           = true; % true if sending triggers to the MEG
setup.Eye           = true; % true if using Eyelink
setup.cancel        = false; % becomes true if escape is pressed, will abort experiment (but save data)
setup.training      = false; % will increase the nr of trials, no pupil rebound, and save under different filename
% use setup.training in the EEG lab for psychophysics

if setup.MEG,
    % add the right paths here
    cd E:\Users\Urai\Desktop\2IFC_RDK_UKE_new;
    % ptb is already on path
    
elseif setup.training,
    cd C:\Users\eeg-lab\Desktop\AnneUrai\2IFC_RDK_UKE;
    addpath(genpath(pwd));
    
    path_ptb = fullfile('C:\Users\eeg-lab\Desktop\TACSATT\Hannah\myPTB');
    addpath(genpath(path_ptb));
end

% ask for subject number, default: 0
setup.participant       = input('Participant number? ');
if isempty(setup.participant), setup.participant = 0; end %test

% which language do they want instructions in
setup.inGerman          = input('Instructions in German? ');
if isempty(setup.inGerman), setup.inGerman = 1; end % German = default

% ask for session number, default: 0
setup.session           = input('Session? 1-5 '); % MEG1, 3x training, MEG2
if isempty(setup.session), setup.session = 0; end % test

% load in individual threshold
try
    load(sprintf('Data/P%d_threshold.mat', setup.participant));
    setup.threshold           = seventypercentthreshold; %take the coherence level that leads to 65% correct
catch
    setup.threshold           = input('This participant''s threshold? 0-1 ');
    
    % save this input for future blocks
    seventypercentthreshold = setup.threshold;
    save(sprintf('Data/P%d_threshold.mat', setup.participant), 'seventypercentthreshold');
end

%% Setup the ParPort
if setup.MEG,
    % install and/or initialize the kernel-level I/O driver
    config_io;
    % optional step: verify that the driver was successfully installed/initialized
    global cogent;
    if( cogent.io.status ~= 0 )
        error('inp/outp installation failed');
    end
    
    % DO NOT USE DUAL MONITOR SETUP ON WINDOWS 7 !!!!!!!
    vswitch(00); % switches to single monitor, will have the taskbar but more accurate timing
end

%% Setup the PsychToolbox

if setup.training,
    window.dist             = 60; % viewing distance in cm , 60 in EEG lab
    window.width            = 53.5; % physical width of the screen in cm, 53.5 for BENQ in EEG lab
    window.height           = 30; % physical height of the screen in cm, 42 for the MEG projector screen inside the scanner
    window.skipChecks       = 0; % set to 1 to skip VBL tests and avoid warnings
    [window, audio]         = SetupPTB_EEGlab(window); %load all the psychtoolbox things in EEG lab
elseif setup.MEG,
    window.dist             = 65; % viewing distance in cm (fixed in the MEG?)
    window.width            = 42; % physical width of the screen in cm, 42 for the MEG projector screen inside the scanner
    window.height           = 32; % physical height of the screen in cm, 42 for the MEG projector screen inside the scanner
    window.skipChecks       = 1; % set to 1 to skip VBL tests and avoid warnings
    [window, audio]         = SetupPTB(window); %load all the psychtoolbox things in MEG
end

if setup.MEG,           window.cogent = cogent;  end % save information about the io details
if setup.Eye,           el = ELconfig(window); end % open the eyetracker config

Screen('TextSize', window.h, 15);
Screen('TextFont', window.h, 'Trebuchet');
Screen('TextColor', window.h, [255 255 255] );
Screen('DrawText',window.h, 'Loading...', window.center(1)*0.60, window.center(2)*0.75 , [255 255 255] );
Screen('Flip', window.h);

% main config
[setup, dots, fix, results, sound, flip, trigger] = configuration(window, audio, setup);

if setup.MEG,
    % make Kb Queue
    keyList = zeros(1, 256); keyList(KbName({'1!', '2@', '3#', '4$', 'ESCAPE','SPACE'})) = 1; % only listen to those keys!
    % first four are the buttons in mode 001, escape and space are for the experimenter
    PsychHID('KbQueueCreate', [], keyList);
    PsychHID('KbQueueStart');
    WaitSecs(.1);
    PsychHID('KbQueueFlush');
    
elseif setup.training,
    % make Kb Queue
    CedrusResponseBox('CloseAll');
    IOPort('CloseAll');
    setup.responsebox = CedrusResponseBox('Open', 'COM9');
    evt = [];
end

for block = 1:setup.nblocks,
    
    if setup.MEG,
        % show the head localization screen to the subject
        vswitch(02);
    end
    
    % block-specific config
    tic;
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
        
        DrawFormattedText(window.h, ...
            sprintf('Loading ... %d %%', round(100*trial/setup.ntrials)), ...
            'center', 'center');
        if setup.MEG,   window  = drawSquares( window ); end
        Screen('Flip', window.h);
    end
    
    DrawFormattedText(window.h, 'Saving ...', ...
        'center', 'center');
    if setup.MEG,   window  = drawSquares( window ); end
    Screen('Flip', window.h);
    
    % save this full config just to be sure
    save(sprintf('Data/Dots_P%d_s%d_b%d_%s.mat', setup.participant, setup.session, block, datestr(now, 'yyyy-mm-dd_HH-MM-SS')), 'coord', '-mat', '-v7.3');
    
    % also save all the data now, in case we have a crash!
    setup.datetime = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
    % create subject specific file and save - add unique datestring to avoid any overwriting of files
    setup.filename = sprintf('Data/P%d_s%d_b%d_%s.mat', setup.participant, setup.session, block, setup.datetime);
    save(setup.filename, '-mat', 'setup', 'window', 'dots', 'fix', 'results', 'audio',  'sound', 'flip', 'trigger');
    disp('SAVED FILE TO DISK'); disp(setup.filename);
    toc;
    
    % in MEG, show squares to position the beamer properly
    if setup.MEG,
        window      = drawSquares( window );
        window      = drawFixation(window, fix, dots); %fixation
        Screen('Flip', window.h);
        vswitch(00);
        
        % wait for keypress to continue with the script
        keyIsDown = false; while ~keyIsDown, keyIsDown = PsychHID('KbQueueCheck'); end
        % show the normal stim screen again
        WaitSecs(0.5);
    end
    
    % eyetracker setup
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
        
        % start recording eye position
        Eyelink('StartRecording');
        % record a few samples before we actually start displaying
        WaitSecs(0.1);
        % mark zero-plot time in data file
        Eyelink('message', 'Start recording Eyelink');
        
    end
    
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
        WaitSecs(3);
        if setup.MEG,
            PsychHID('KbQueueFlush'); % at the beginning of each block
            keyIsDown = false; while ~keyIsDown, keyIsDown = PsychHID('KbQueueCheck'); end
            PsychHID('KbQueueFlush'); % at the beginning of each block
        else
            CedrusResponseBox('WaitButtonPress', setup.responsebox);
        end
        WaitSecs(.3);
    end
    
    %% start the loop over trials
    for trial = 1:setup.ntrials,
        
        if setup.MEG, PsychHID('KbQueueFlush'); end
        if setup.Eye,
            Eyelink ('Message', 'blinkbreak_start');
        end
        
        window      = drawAllDots(window, dots, 1, trial, coord.fix, 1);
        window      = drawFixation(window, fix, dots); %fixation
        Screen('Flip', window.h); % flip once, so stationary dots
        if setup.MEG, 
            outp(trigger.address, trigger.blinkbreakstart); 
            WaitSecs(trigger.width);outp(trigger.address, trigger.zero); 
        end

        % wait for buttonpress
        if setup.MEG,
            keyIsDown = false; while ~keyIsDown, keyIsDown = PsychHID('KbQueueCheck'); end
        elseif setup.training,
            CedrusResponseBox('WaitButtonPress', setup.responsebox);
        end
        
        if setup.Eye,
            Eyelink ('Message', 'blinkbreak_end');
        end
          
        %% stimulus sequence onset
        
        % from this moment on, start to check if they are not already
        % pressing buttons!
        WronglyPressed = false;
        if setup.MEG,
            keyIsDown = false;
            PsychHID('KbQueueFlush'); 
        elseif setup.training,
            CedrusResponseBox('FlushEvents', setup.responsebox);    
            evt = [];
        end
        
        % FIXATION
        if setup.Eye, Eyelink('command', 'record_status_message ''trial %d''', trial);
            Eyelink ('Message', sprintf('block%d_trial%d_fix', block, trial));
        end
        
        for frameNum = 1:ceil(setup.fixtime(block, trial)*window.frameRate),
            
            window      = drawAllDots(window, dots, 1, trial, coord.fix, frameNum);
            window      = drawFixation(window, fix, dots); % fixation
            
            [flip.fix.VBL(block, trial, frameNum), ...
                flip.fix.StimOns(block, trial, frameNum), ...
                flip.fix.FlipTS(block, trial, frameNum), ...
                flip.fix.Missed(block, trial, frameNum), ...
                flip.fix.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
            
            if frameNum == 1,
                if setup.MEG, outp(trigger.address, trigger.fix); end
            end
            if frameNum == 2,
                % parport zero
                if setup.MEG, outp(trigger.address, trigger.zero); end
            end
            
            % check that no button is pressed
            if setup.MEG,
                [keyIsDown, firstPress] = PsychHID('KbQueueCheck');
            elseif setup.training,
                evt = CedrusResponseBox('GetButtons', setup.responsebox);
            end
        end
        
        if setup.Eye, Eyelink ('Message', sprintf('block%d_trial%d_ref', block, trial)); end
        
        % play reference stimulus onset tone
        PsychPortAudio('SetLoop',audio.h, sound.tonepos(1,1), sound.tonepos(1,2));
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
            
            if frameNum == 1,
                % parport UP
                if setup.MEG, outp(trigger.address, trigger.ref); end
            end
            if frameNum == 2,
                % parport zero
                if setup.MEG, outp(trigger.address, trigger.zero); end
            end
            
            % check that no button is pressed
            if setup.MEG,
                [keyIsDown, firstPress] = PsychHID('KbQueueCheck');
            elseif setup.training,
                evt = CedrusResponseBox('GetButtons', setup.responsebox);
            end
        end
        
        if setup.Eye, Eyelink ('Message', sprintf('block%d_trial%d_interval', block, trial)); end
        
        % INTERVAL
        for frameNum = 1:ceil(setup.intervaltime(block, trial)*window.frameRate),
            
            window      = drawAllDots(window, dots, 1, trial, coord.interval, frameNum);
            window      = drawFixation(window, fix, dots); % fixation
            
            [flip.interval.VBL(block, trial, frameNum), ...
                flip.interval.StimOns(block, trial, frameNum), ...
                flip.interval.FlipTS(block, trial, frameNum), ...
                flip.interval.Missed(block, trial, frameNum), ...
                flip.interval.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
            
            if frameNum == 1,
                % parport UP
                if setup.MEG, outp(trigger.address, trigger.interval); end
            end
            if frameNum == 2,
                % parport zero
                if setup.MEG, outp(trigger.address, trigger.zero); end
            end
            
            % check that no button is pressed
            if setup.MEG,
                [keyIsDown, firstPress] = PsychHID('KbQueueCheck');
            elseif setup.training,
                evt = CedrusResponseBox('GetButtons', setup.responsebox);
            end
        end
        
        if setup.Eye, Eyelink ('Message', sprintf('block%d_trial%d_stim_inc%d', block, trial, setup.increment(block, trial))); end
        
        % play test stimulus onset tone
        PsychPortAudio('SetLoop',audio.h, sound.tonepos(1,1), sound.tonepos(1,2));
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
            
            if frameNum == 1,
                % parport UP
                if setup.MEG, outp(trigger.address, trigger.stim(block, trial)); end
            end
            if frameNum == 2,
                % parport zero
                if setup.MEG, outp(trigger.address, trigger.zero); end
            end
            
            % check that no button is pressed
            if setup.MEG,
                [keyIsDown, firstPress] = PsychHID('KbQueueCheck');
                if keyIsDown, WronglyPressed = true; end
            elseif setup.training,
                evt = CedrusResponseBox('GetButtons', setup.responsebox);
                if ~isempty(evt),   WronglyPressed = true; end
            end
        end
     
        if ~WronglyPressed,
            
            %% RESPONSE
            if setup.MEG,
                PsychHID('KbQueueFlush'); % at the beginning of each block
                evt = [];
            else
                CedrusResponseBox('FlushEvents', setup.responsebox);
                evt = [];
            end
            keyIsDown = false; frameNum = 1;
            
            while GetSecs-flip.stim.VBL(block,trial,setup.nframes) < setup.resptime && (~keyIsDown && isempty(evt)),
                % when no response has been given, and the maximum response time hasnt been reached
                
                window      = drawAllDots(window, dots, 1, trial, coord.resp, frameNum);
                window      = drawFixation(window, fix, dots); % fixation
                
                % record response
                if setup.MEG,
                    [keyIsDown, firstPress] = PsychHID('KbQueueCheck');
                elseif setup.training,
                    evt = CedrusResponseBox('GetButtons', setup.responsebox);
                end
                
                [flip.resptime.VBL(block, trial, frameNum), ...
                    flip.resptime.StimOns(block, trial, frameNum), ...
                    flip.resptime.FlipTS(block, trial, frameNum), ...
                    flip.resptime.Missed(block, trial, frameNum), ...
                    flip.resptime.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
                frameNum = frameNum + 1;
            end %button pressed

            if keyIsDown || ~isempty(evt),
                
                results.resptime(block, trial)      = GetSecs();
                results.RT(block, trial)            = results.resptime(block, trial) - flip.stim.VBL(block,trial, setup.nframes);
                
                if setup.MEG,
                    results.firstPress{block, trial}    = firstPress;
                    results.key{block, trial}           = KbName(firstPress); %save the full output of the key
                    
                    switch mod(setup.participant, 2);
                        case 0 %Screen('DrawText',window.h,  'Press left for weaker and right for stronger motion',  window.center(1)*0.60, window.center(2)*0.55 , [255 255 255] );
                            switch KbName(firstPress)
                                case '1!', % left target 1, right target 2
                                    results.response(block, trial) = -1;
                                case '2@', % left target 1, right target 2
                                    results.response(block, trial) = -1;
                                case '3#',
                                    results.response(block, trial) = 1;
                                case '4$',
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
                            switch KbName(firstPress)
                                case '1!', % left target 1, right target 2
                                    results.response(block, trial) = 1;
                                case '2@', % left target 1, right target 2
                                    results.response(block, trial) = 1;
                                case '3#',
                                    results.response(block, trial) = -1;
                                case '4$',
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
                    
                elseif setup.training,
                    
                    results.firstPress{block, trial}    = evt.buttonID;
                    
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
                end
            else
                %if no key was pressed, NaN
                results.response(block, trial)      = NaN;
                results.resptime(block, trial)      = GetSecs(); % to know when to start counting for pupilrebound
            end
 
            % response trigger is sent in the next loop of frame drawing to
            % avoid flip glitches, see below
            
            % code for correct responses
            if results.response(block, trial) == setup.increment(block,trial), %whether motion is stronger than 50% or not
                results.correct(block,trial) = true;
            elseif results.response(block, trial) == -1 * setup.increment(block,trial), %whether motion is stronger than 50% or not
                results.correct(block,trial) = false;
            elseif isnan(results.response(block, trial)),
                results.correct(block,trial) = NaN;
                results.RT(block,trial) = NaN; %set RT to NaN to easily filter out trials without a response
            else 
                setup.cancel; % if response is anything else
            end
            
        else
            % if there was a too early press, give NaN feedback
            results.correct(block, trial) = NaN;
            results.resptime(block, trial)      = GetSecs(); % to know when to start counting for pupilrebound
        end
        
        % send all information in one trigger to EyeLink
        if setup.Eye, Eyelink ('Message', sprintf('block%d_trial%d_resp_key%d_correct%d', block, trial, results.response(block, trial), results.correct(block, trial))); end
        
        % WAIT FOR THE PUPIL TO RETURN TO BASELINE
        WronglyPressed = false;
        if setup.MEG,
            keyIsDown = false;
            PsychHID('KbQueueFlush'); % at the beginning of each block
        elseif setup.training,
            evt = [];
            CedrusResponseBox('FlushEvents', setup.responsebox);
        end
        
        frameNum = 1;
        while GetSecs < setup.pupilreboundtime(block, trial)+results.resptime(block, trial);
            
            window      = dots_noise_draw(window, dots);
            window      = drawFixation(window, fix, dots); % fixation
            
            [flip.pupilrebound1.VBL(block, trial, frameNum), ...
                flip.pupilrebound1.StimOns(block, trial, frameNum), ...
                flip.pupilrebound1.FlipTS(block, trial, frameNum), ...
                flip.pupilrebound1.Missed(block, trial, frameNum), ...
                flip.pupilrebound1.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
            
            % send response trigger when pupilrebound begins!
            % sending it in the loop will avoid the screen to hang
            if setup.MEG && frameNum == 1,
                % trigger
                switch results.response(block, trial),
                    case -1 % weaker
                        outp(trigger.address, trigger.resp.weaker);
                    case 1 % stronger
                        outp(trigger.address, trigger.resp.stronger);
                    otherwise %send a different trigger for no response
                        outp(trigger.address, trigger.resp.noresp);
                end
            elseif setup.MEG && frameNum == 2,
                outp(trigger.address, trigger.zero);
            end
            
            frameNum = frameNum + 1;
            
            % to ensure that no extra button is pressed
            if setup.MEG,
                [keyIsDown, firstPress] = PsychHID('KbQueueCheck');
                if keyIsDown, WronglyPressed = true; end
            elseif setup.training,
                evt = CedrusResponseBox('GetButtons', setup.responsebox);
                if ~isempty(evt) && evt.action==1,
                    % ensure that we are only counting press, not release, of the button
                    WronglyPressed = true; 
                end
            end
        end

        if WronglyPressed, results.correct(block, trial) = NaN; end
        
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
        
        if setup.Eye, Eyelink ('Message', sprintf('block%d_trial%d_feedback_correct%d', block, trial, results.correct(block, trial))); else
        fprintf('\n block%d_trial%d_correct%d', block, trial, results.correct(block, trial)); end
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
            
            if setup.MEG && frameNum == 1,
                % feedback trigger
                switch results.correct(block, trial),
                    case 0 % wrong
                        outp(trigger.address, trigger.feedback.incorrect);
                    case 1 % correct
                        outp(trigger.address, trigger.feedback.correct);
                    otherwise %send a different trigger for no response
                        outp(trigger.address, trigger.feedback.noresp);
                end
            elseif setup.MEG && frameNum == 2,
                outp(trigger.address, trigger.zero);
            end
            
            frameNum = frameNum + 1;
        end
        
        % break out of all trials if ESC was pressed
        if setup.cancel,
            break
            warning('experiment was manually terminated');
        end
        
    end %end trial loop
    
    %% break text
    if block < setup.nblocks,
        if setup.inGerman,
            DrawFormattedText(window.h, sprintf('Fertig mit Block %d! \n \n Sie haben %.2f Prozent an Versuchsdurchgängen richtig beantwortet \n \n und Ihre mittlere Reaktionszeit war %.2f Sekunden. \n \n\n \n', ...
                block, nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:))), 'center', 'center');
        else
            DrawFormattedText(window.h, sprintf('Finished block %d! \n \n You answered %.2f percent of trials correct, \n \n and your average reaction time was %.2f seconds. \n \n\n \n', ...
                block, nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:))), 'center', 'center');
        end
    else % finish
        if setup.inGerman,
            DrawFormattedText(window.h, sprintf('Fertig mit Block %d! \n \n Sie haben %.2f Prozent an Versuchsdurchgängen richtig beantwortet \n \n und Ihre mittlere Reaktionszeit war %.2f Sekunden. \n \n\n \n', ...
                block, nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:))), 'center', 'center');
        else
            DrawFormattedText(window.h, sprintf('Finished block %d! \n \n You answered %.2f percent of trials correct, \n \n and your average reaction time was %.2f seconds. \n \n\n \n', ...
                block, nanmean(results.correct(block,:))*100, nanmean(results.RT(block,:))), 'center', 'center');
        end
    end
    Screen('Flip', window.h);
        
    % also show this info in the command window
    fprintf('Finished block %d! \n \n You answered %.2f percent of trials correct, \n \n and your average reaction time was %.2f seconds.', ...
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
    
    % wait for keypress to start with the next block
    if setup.MEG,
        WaitSecs(.1);
        keyIsDown = false; while ~keyIsDown, keyIsDown = PsychHID('KbQueueCheck'); end
    elseif setup.training,
        evt = CedrusResponseBox('WaitButtonPress', setup.responsebox);
    end
    
end

% wrap up and save after the last block
setup.datetime = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
% create subject specific file and save - add unique datestring to avoid any overwriting of files
setup.filename = sprintf('Data/P%d_s%d_%s.mat', setup.participant, setup.session, setup.datetime);
save(setup.filename, '-mat', 'setup', 'window', 'dots', 'fix', 'results', 'audio',  'sound', 'flip', 'trigger');
disp('SAVED FILE TO DISK'); disp(setup.filename);

% close the eyelink
if setup.Eye == true,
    Eyelink('StopRecording');
end

% exit gracefully
disp('done!'); Screen('CloseAll'); ShowCursor;
PsychPortAudio('Stop', audio.h);
if setup.MEG,
    PsychHID('KbQueueStop');
end
sca;

% conduct quick timing test
setup.thresholding = false;
testmissedflips(window,flip, setup);

msgbox('DO NOT FORGET TO CHANGE NR OF TRIALS BACK');

