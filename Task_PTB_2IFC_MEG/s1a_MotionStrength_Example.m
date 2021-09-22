%% Motion strength example
% shows a random dot stimulus with a direction specific to the subject
% each trial decreases in motion strength
%
% Edited: Anne Urai, 26 May 2015
% -----------------------------------------------------------------

clear all; close all; clc;
cd C:\Users\eeg-lab\Desktop\AnneUrai\2IFC_RDK_UKE;
addpath(genpath(pwd));

path_ptb = fullfile('C:\Users\eeg-lab\Desktop\TACSATT\Hannah\myPTB');
addpath(genpath(path_ptb));

% general setup
setup.Eye               = false; % true if using Eyelink (will use pupil rebound time as well)
setup.MEG               = false; % true if sending triggers to the MEG
setup.thresholding      = true;
setup.cancel            = false;

% ask for subject number, default: 0
setup.participant       = input('Participant number? ');
if isempty(setup.participant), setup.participant = 0; end

setup.inGerman          = input('Instructions in German? ');
if isempty(setup.inGerman), setup.inGerman = 1; end % German = default

%% Setup the ParPort
if setup.MEG,
    % install and/or initialize the kernel-level I/O driver
    config_io;
    % optional step: verify that the driver was successfully installed/initialized
    global cogent;
    if( cogent.io.status ~= 0 )
        error('inp/outp installation failed');
    end
    vswitch(00);
end

%% Setup the PsychToolbox
window.dist             = 60; % viewing distance in cm , 60 in EEG lab
window.width            = 53.5; % physical width of the screen in cm, 53.5 for BENQ in EEG lab
window.height           = 30; % physical height of the screen in cm, 42 for the MEG projector screen inside the scanner
window.skipChecks       = 0; % set to 1 to skip VBL tests and avoid warnings
[window, audio]         = SetupPTB_EEGlab(window); %load all the psychtoolbox things
if setup.MEG,           window.cogent = cogent;  end %save information about the io details
if setup.Eye,           ELconfig(window); end

%% CONFIGURATION

[setup, dots, fix, results, sound, flip, coord, trigger] = configuration_motionstrength_example(window, audio, setup);

% make Kb Queue
CedrusResponseBox('CloseAll');
IOPort('CloseAll');
setup.responsebox = CedrusResponseBox('Open', 'COM9');
evt = [];

%% INSTRUCTIONS
Screen('TextSize', window.h, 20);
Screen('TextFont', window.h, 'Trebuchet');
Screen('TextColor', window.h, [255 255 255] );

if setup.inGerman,
    DrawFormattedText(window.h, ['Willkommen zu meinem Experiment! \n \n', ...
        'Sie werden durch die Instruktionen geführt. \n\n', ...
        'Bitte lesen Sie die Anweisungen sorgfültig durch \n\n ', ...
        'und drücken Sie eine Taste um zum nächsten Bildschirm zu gelangen. ', ...
        '\n\n Wenn Sie Fragen haben \n\n', ...
        ' fragen Sie bitte den Versuchsleiter.'],  'center', 'center');
else
    DrawFormattedText(window.h, ['Welcome to my experiment! \n \n', ...
        'You will be guided through instructions. \n\n', ...
        'Please read the instructions carefully, \n\n ', ...
        'and press a key to continue to the next screen. ', ...
        '\n\n If you have any questions, \n\n', ...
        ' please ask the experimenter.'],  'center', 'center');
end

Screen('Flip', window.h);
CedrusResponseBox('WaitButtonPress', setup.responsebox);

if setup.inGerman,
    DrawFormattedText(window.h, ['Das Experiment besteht aus sich wiederholenden ''Versuchsdurchgängen'' desselben Stimulus. \n\n' ...
        'Jeder Durchgang beginnt mit einer Wolke weißer Punkte auf einem schwarzen Bildschirm. \n\n \n\n' ...
        'In der Mitte der Wolke ist ein roter Fixpunkt: \n\n', ...
        'Es ist wichtig, dass Sie Ihre Augen auf diesen Punkt fixieren \n\n' ...
        'und Ihre Augen nicht zu den weißen Punkten bewegen.'], ...
        'center', 'center');
else
    DrawFormattedText(window.h, ['The experiment consists of repeated ''trials'' of the same stimulus. \n\n' ...
        'Each trials begins with a cloud of white dots on a black screen. \n\n \n\n' ...
        'In the middle of the cloud is a red fixation circle: \n\n', ...
        'it is important that you focus your eyes here, \n\n' ...
        'and do not move your eyes to the white dots.'], ...
        'center', 'center');
end

Screen('Flip', window.h);
CedrusResponseBox('WaitButtonPress', setup.responsebox);

window      = dots_noise_draw(window, dots);
window      = drawFixation(window, fix, dots); %fixation
Screen('Flip', window.h); % flip once, so stationary dots
CedrusResponseBox('WaitButtonPress', setup.responsebox);


if setup.inGerman,
    
    % do some randomization
    switch mod(setup.participant, 4),
        case 0 %        dots.direction = 45;
            direction = 'unten rechts';
        case 1 %        dots.direction = 135;
            direction = 'unten links';
        case 2 %        dots.direction = 225;
            direction = 'oben links';
        case 3 %        dots.direction = 315;
            direction = 'oben rechts';
    end
    
    DrawFormattedText(window.h, ['Zu Beginn jedes Durchgangs werden Sie einen kurzen Ton hören \n\n' ...
        ' und die Punkte werden beginnen, sich nach ' direction ' zu bewegen.'], 'center', 'center' );
else
    
    % do some randomization
    switch mod(setup.participant, 4),
        case 0 %        dots.direction = 45;
            direction = 'lower right';
        case 1 %        dots.direction = 135;
            direction = 'lower left';
        case 2 %        dots.direction = 225;
            direction = 'upper left';
        case 3 %        dots.direction = 315;
            direction = 'upper right';
    end
    
    DrawFormattedText(window.h, ['At the beginning of each trial, you will hear a short beep \n\n' ...
        ' and the dots will start to move towards the ' direction ' of the screen.'], 'center', 'center' );
end
Screen('Flip', window.h);
CedrusResponseBox('WaitButtonPress', setup.responsebox);

%% Start looping through the blocks trials
for block = 1:setup.nblocks,
    
    if setup.MEG,
        % show the head localization screen to the subject
        vswitch(02);
        keyIsDown = false; while ~keyIsDown, keyIsDown = PsychHID('KbQueueCheck'); end
        % show the normal stim screen again
        vswitch(01);
    end
    
    if setup.Eye == true,
        %  open edf file for recording data from Eyelink
        % CANNOT BE MORE THAN 8 CHARACTERS
        edfFile = sprintf('%ds%db%d.edf', setup.participant, setup.session, block);
        Eyelink('Openfile', edfFile);
        
        % send information that is written in the preamble
        preamble_txt = sprintf('%s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %d', ...
            'Experiment', 'Thresholding', ...
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
        
        if trial == 1, % draw new dots, otherwise keep the ones from the last trial
            window      = drawAllDots(window, dots, block, trial, coord.fix, 1);
            window      = drawFixation(window, fix, dots); %fixation
            Screen('Flip', window.h); % flip once, so stationary dots
        end
        
        WaitSecs(.1);
        %CedrusResponseBox('WaitButtonPress', setup.responsebox);
        
        %% stimulus sequence onset
        % FIXATION
        
        if setup.MEG, outp(trigger.address, trigger.fix); WaitSecs(trigger.width); outp(trigger.address, trigger.zero);  end
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
        end
        
        % play reference stimulus onset tone
        PsychPortAudio('SetLoop',audio.h, sound.tonepos(1,1), sound.tonepos(1,2));
        PsychPortAudio('Start', audio.h); %like flip
        
        % triggers
        if setup.MEG, outp(trigger.address, trigger.ref); WaitSecs(trigger.width); outp(trigger.address, trigger.zero);  end
        if setup.Eye, Eyelink ('Message', sprintf('block%d_trial%d_ref', block, trial)); end
        
        % TEST STIMULUS
        for frameNum = 1:setup.nframes,
            window      = drawAllDots(window, dots, block, trial, coord.stim, frameNum);
            window      = drawFixation(window, fix, dots);
            
            [flip.stim.VBL(block, trial, frameNum), ...
                flip.stim.StimOns(block, trial, frameNum), ...
                flip.stim.FlipTS(block, trial, frameNum), ...
                flip.stim.Missed(block, trial, frameNum), ...
                flip.stim.beampos(block, trial, frameNum)] = Screen('Flip', window.h);
        end
        
        
        % break out of all trials if ESC was pressed
        if setup.cancel,
            break
            warning('experiment was manually terminated');
        end
        if trial == 1,
            WaitSecs(1);
            if setup.inGerman,
                DrawFormattedText(window.h,  ['Sie konnten deutlich sehen wohin sich die Punkte bewegen. \n\n' ...
                    'Das bedeutet, dass die Bewegung STARK ist und, dass alle Punkte sich in dieselbe Richtung bewegen. '] , 'center', 'center');
            else
                DrawFormattedText(window.h,  ['You could clearly see where the dots were moving. \n\n' ...
                    'This means the motion is STRONG, and that all the dots move towards the same direction. '] , 'center', 'center');
            end
            Screen('Flip', window.h);
            CedrusResponseBox('WaitButtonPress', setup.responsebox);
            
            if setup.inGerman,
                DrawFormattedText(window.h, ['Es kann auch sein, dass die Punkte zufällig flackern \n\n' ...
                    'was es schwieriger macht, die Bewegungsrichtung zu sehen. \n\n' ...
                    'Wenn das passiert ist die Bewegung SCHWACH. '] , 'center', 'center');
            else
                DrawFormattedText(window.h, ['It can also be that the dots are flickering randomly, \n\n' ...
                    'making it more difficult to see the direction of motion. \n\n' ...
                    'When this happens, the motion is WEAK. '] , 'center', 'center');
            end
            
            Screen('Flip', window.h);
            CedrusResponseBox('WaitButtonPress', setup.responsebox);
            
            if setup.inGerman,
                DrawFormattedText(window.h,  ['Im restlichen Experiment bewegen sich die Punkte immer in diesselbe Richtung. \n\n' ...
                    ' Aber die STARKE der Bewegung der Punktwolke kann sich verändern: \n\n ' ...
                    ' Das ist wichtig für Ihre Aufgabe. \n\n\n\n' ...
                    ' Sie werden jetzt ein paar Beispiele sehen, \n\n' ...
                    ' die von sehr starker bis hin zu sehr schwacher Bewegung reichen.'] , 'center', 'center');
            else
                DrawFormattedText(window.h,  ['In the rest of the experiment, the dots will always move in the same direction. \n\n' ...
                    ' However, the motion STRENGTH of the cloud of dots may differ: \n\n ' ...
                    'this is important for the task you will do. \n\n\n\n' ...
                    ' You will now see a series of examples \n\n' ...
                    ' that go from very strong to very weak motion.'] , 'center', 'center');
            end
            Screen('Flip', window.h);
            CedrusResponseBox('WaitButtonPress', setup.responsebox);
        end
        
    end %end trial loop
    
    if block < setup.nblocks,
        Screen('DrawText',window.h, 'Take a break!', window.center(1)*0.6, window.center(2), [255 255 255] );
    else % finish
        Screen('DrawText',window.h, 'Done!', window.center(1)*0.60, window.center(2) , [255 255 255] );
    end
    Screen('Flip', window.h);
    WaitSecs(4);

    % break out of all trials if ESC was pressed
    if setup.cancel,
        break
        warning('experiment was manually terminated');
    end
    
end %end block loop

% close the eyelink
if setup.Eye == true,
    Eyelink('StopRecording');
end

% exit gracefully
disp('done!'); Screen('CloseAll'); ShowCursor;
PsychPortAudio('Stop', audio.h);
sca;
