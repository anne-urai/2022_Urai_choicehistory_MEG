%% Fixation screen for resting state session
% Anne Urai, UKE, April 2014
% -----------------------------------------------------------------

clear all; close all; clc;
try
    cd E:\Users\Urai\Desktop\2IFC_RDK;
end
addpath(genpath(pwd));

% general setup213
setup.Eye           = true; % true if using Eyelink (will use pupil rebound time as well)
setup.MEG           = true; % 3222true if sending triggers to the MEG

% time of the resting state run in seconds
setup.waittime      = 5*60; % five MINUTES
disp('starting resting state, duration:'); disp(setup.waittime);disp('seconds');

% ask for subject number, default: 0
setup.participant       = input('Participant number? ');
if isempty(setup.participant), setup.participant = 0; end

setup.inGerman          = input('Instructions in German? ');
if isempty(setup.inGerman), setup.inGerman = 1; end % English = default

% ask for session number, default: 0
setup.session           = input('Session? 1 or 5 ');
if isempty(setup.session), setup.session = 0; end

%% Setup the PsychToolbox
window.dist             = 65; % viewzbing distance in cm (fixed in the MEG?)
window.width            = 42; % physical width of the screen in cm, 42 for the MEG projector screen inside the scanner
window.height           = 32; % physical height of the screen in cm, 42 for the MEG projector screen inside the scanner
window.skipChecks       = 1; % set to 1 to skip VBL tests and avoid warnings
[window, audio]         = SetupPTB(window); %load all the psychtoolbox things
if setup.Eye,           el = ELconfig(window); end

dots.innerspace     = deg2pix(window, 2);
fix.dotsize         = deg2pix(window,0.15); % fixation dot
fix.circlesize      = deg2pix(window,0.6); % circle around fixation dot
fix.color           = [255 0 0]; %red

Screen('TextSize', window.h, 15);
Screen('TextFont', window.h, 'Trebuchet');
Screen('TextColor', window.h, [255 255 255] );

if setup.Eye == true,
    %  open edf file for recording data from Eyelink
    % CANNOT BE MORE THAN 8 CHARACTERS
    edfFile = sprintf('RS%ds%d.edf', setup.participant, setup.session);
    Eyelink('Openfile', edfFile);
    
    % send information that is written in the preamble
    preamble_txt = sprintf('%s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %s %d', ...
        'Experiment', 'RestingState', ...
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
    %EyelinkDoDriftCorrection(el);
    
    % start recording eye position
    Eyelink('StartRecording');
    % record a few samples before we actually start displaying
    WaitSecs(0.1);
    % mark zero-plot time in data file
    Eyelink('message', 'Start recording Eyelink');
    
end

%% Setup the ParPort
if setup.MEG,
    trigger.address      = hex2dec('378');
    trigger.zero         = 0;
    trigger.width        = 0.01; %10 ms trigger signal
    trigger.start        = 1;
    trigger.end          = 2;
    
    % install and/or initialize the kernel-level I/O driver
    config_io;
    % optional step: verify that the driver was successfully installed/initialized
    global cogent;
    if( cogent.io.status ~= 0 )
        error('inp/outp installation failed');
    end
    vswitch(00);
end

if setup.MEG,           window.cogent = cogent;  end %save information about the io details

if setup.MEG,
    % let the participants get used to the head localization screen
    vswitch(02);
    KbWait;
    vswitch(00);
end

if setup.inGerman,
    DrawFormattedText(window.h, ['Während dieses Blocks, werden Sie nur den roten Fixationpunkt sehen. \n\n', ...
        ' Bitte fixieren Sie in dieser Zeit weiterhin den Roten Fixationspunkt.', ...      
        ' Versuchen Sie den Kopf so still wie möglich zu halten. \n\n', ...
        ' Die Ruhemessung wird fünf Minuten dauern. \n\n'],  'center', 'center');
else
    DrawFormattedText(window.h, ['In this session, you will only see the \n\n', ...
        'red fixation point in the center of the screen. \n\n', ...
        ' Keep your eyes fixated there. \n\n', ...
        ' You can blink when you need to. \n\n', ...
        ' Try to keep your head as still as possible. \n\n', ...
        ' This resting session will take five minutes. \n\n'],  'center', 'center');
end
Screen('Flip', window.h);
KbWait;

%% Present the fixation
window      = drawFixation(window, fix, dots); %fixation

Screen('Flip', window.h);

if setup.MEG, outp(trigger.address, trigger.start); WaitSecs(trigger.width); outp(trigger.address, trigger.zero);  end
if setup.Eye, Eyelink ('Message', 'Start_Fixation');    end

%% now wait for the duration specified
for fraction = 1:10, % in a five minute block, send some trigger every 10s
    
    if setup.MEG, outp(trigger.address, trigger.start); WaitSecs(trigger.width); outp(trigger.address, trigger.zero);  end
    if setup.Eye, Eyelink ('Message', 'Start_Fixation');    end
    
    % now wait
  WaitSecs(setup.waittime/10);
end

%%

if setup.MEG, outp(trigger.address, trigger.end); WaitSecs(trigger.width); outp(trigger.address, trigger.zero);  end
if setup.Eye, Eyelink ('Message', 'End_Fixation');    end

%% wrap up

% save the EL file for this block
if setup.Eye,
    
    setup.datetime      = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
    setup.eyefilename   = sprintf('Data/MEG_P%d_restingstate_%s.edf', setup.participant, setup.datetime);
    Eyelink('CloseFile');
    Eyelink('WaitForModeReady', 500);
    try
        status              = Eyelink('ReceiveFile',edfFile, setup.eyefilename); %this collects the file from the eyelink
        disp(['File ' setup.eyefilename ' saved to disk']);
    catch
        warning(['File ' setup.eyefilename ' not saved to disk']);
    end
end

% wrap up and save
setup.datetime = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
% create subject specific file and save - add unique datestring to avoid any overwriting of files
setup.filename = sprintf('Data/MEG_P%d_restingstate_%s.mat', setup.participant, setup.datetime);
save(setup.filename, '-mat');

% close the eyelink
if setup.Eye == true,
    Eyelink('StopRecording');
end

window      = drawFixation(window, fix, dots); %fixation
Screen('DrawText',window.h, 'Done!', window.center(1)*0.60, window.center(2)*0.75 , [255 255 255] );

Screen('Flip', window.h);
KbWait;

% exit gracefully
disp('done!'); Screen('CloseAll'); ShowCursor;
PsychPortAudio('Stop', audio.h);
sca;
