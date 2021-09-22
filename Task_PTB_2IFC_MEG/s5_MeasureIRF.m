%% Measure Individual IRF
% To measure the individual impulse response functions of the pupil
% during short audio tones
% Timing of tones is drawn randomly from a uniform distribution:
% [setup.lower, setup.upper]

% Measure Dummy Pupil Script by Anne Urai, March 2014
% Adapted by Olympia Colizoli, May 2015
% ----------------------------------------------------------------

clear all; close all; clc;
cd E:\Users\Urai\Desktop\2IFC_RDK_UKE_new;

% general setup
setup.MEG           = true; % true if sending triggers to the MEG
setup.Eye           = true; % true if using Eyelink

% ask for subject number, default: 0
setup.participant       = input('Participant number? ');
if isempty(setup.participant),    setup.participant   = 100; end

setup.inGerman          = input('Instructions in German? ');
if isempty(setup.inGerman), setup.inGerman = 1; end % English = default

% ask for block number, default: 0
setup.session        = input('Session? ');
if isempty(setup.session),   setup.session    = 0; end

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
    % vswitch(00); % switches to single monitor, will have the taskbar but more accurate timing
end

window.dist             = 65; % viewing distance in cm (fixed in the MEG?)
window.width            = 42; % physical width of the screen in cm, 42 for the MEG projector screen inside the scanner
window.height           = 32; % physical height of the screen in cm, 42 for the MEG projector screen inside the scanner
window.skipChecks       = 1; % set to 1 to skip VBL tests and avoid warnings
[window, audio]         = SetupPTB(window); %load all the psychtoolbox things in MEG

if setup.MEG,           window.cogent = cogent;
    trigger.address      = hex2dec('378');
    trigger.beep = 100;
    trigger.width = 0.010;
    trigger.zero = 0;
end % save information about the io details

%% audio setup

setup.nbeeps        = 100; % number of trials/tones
setup.lower         = 2; % lower limit for duration in secs
setup.upper         = 12; % upper limit for duration in secs

% random uniform distribution on interval = [noise.lower,noise.upper]
setup.beeps = setup.lower + (setup.upper-setup.lower).*rand(setup.nbeeps,1);

% rather, draw samples from exp dist with a specified range
setup.beeps         = exprnd(2, 300, 1);

[sound.tonebuf, sound.tonepos] = CreateAudioBuffer(CreateTone(440, 0.050, audio.freq));
PsychPortAudio('FillBuffer', audio.h, sound.tonebuf);

if setup.Eye,           
    el = ELconfig(window);
    
    %  open edf file for recording data from Eyelink - CANNOT BE MORE THAN 8 CHARACTERS
    edfFile = sprintf('%ds%dIRF.edf', setup.participant, setup.session);
    Eyelink('Openfile', edfFile);
    
    % send information that is written in the preamble
    preamble_txt = sprintf('%s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %d', ...
        'Experiment', 'IRFmeasurement', ...
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
    
end % open the eyetracker config

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% INITIALIZE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fix = setupFix(window);
dots.innerspace        = deg2pix(window, 2);

Screen('TextSize', window.h, 15);
Screen('TextFont', window.h, 'Trebuchet');
Screen('TextColor', window.h, [255 255 255] );

if setup.inGerman,
    DrawFormattedText(window.h, ['W?hrend dieses Blocks, werden Sie in unregelm?ssigen Intervallen T?ne h?ren. \n \n '...
        'Bitte fixieren Sie in dieser Zeit weiterhin den Roten Fixationspunkt,', ...
        'und z?hlen Sie die T?ne.'],  'center', 'center');
else
    DrawFormattedText(window.h, ['During this block, you will hear beeps at irregular intervals. \n \n '...
        'Keep looking at the red fixation point, and count the number of beeps.'],  'center', 'center');
end
Screen('Flip', window.h);

    KbWait; % experimenter presses buton
window      = drawFixation(window, fix, dots); %fixation
Screen('Flip', window.h);

%% Present sounds at random intervals

% present the actual beeps!
for i=1:length(setup.beeps),
        
    WaitSecs(setup.beeps(i));
    % change tone here:
    PsychPortAudio('SetLoop',audio.h, sound.tonepos(1,1), sound.tonepos(1,2)); % prepare tone
    PsychPortAudio('Start', audio.h); %like flip
    if setup.Eye,
        Eyelink ('Message', sprintf('beep_%d', i));
         Eyelink('command', 'record_status_message ''beep %d''', i)
    end
    if setup.MEG,
        outp(trigger.address, trigger.beep);
        WaitSecs(trigger.width);
        outp(trigger.address, trigger.zero);
    end
    
end

WaitSecs(3);

if setup.Eye
    Eyelink ('Message', sprintf('measuring ended at %d', GetSecs));
end

DrawFormattedText(window.h, ['Done!'],  'center', 'center');
Screen('Flip', window.h);

%% save the EL file for this block
if setup.Eye
    setup.datetime = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
    %  fprintf('Receiving data file ''%s''\n', edfFile );
    setup.eyefilename = sprintf('Data/P%d_%s_IRF.edf', setup.participant,setup.datetime);
    status = Eyelink('ReceiveFile', edfFile, setup.eyefilename); %this collects the file from the eyelink
    disp(status);
    disp(['File ' setup.eyefilename ' saved to disk']);
    % close the eyelink
    Eyelink('StopRecording');
    Eyelink('CloseFile');
    
    %-------------
    % Create subject specific file and save - add unique datestring to avoid any overwriting of files
    %-------------
    setup.filename = sprintf('Data/P%d_%s_IRF.mat', setup.participant, setup.datetime);
    save(setup.filename, '-mat', 'sound', 'window', 'audio', 'setup', 'fix');
end

disp('done!'); Screen('CloseAll'); ShowCursor;
PsychPortAudio('Stop', audio.h);
sca;