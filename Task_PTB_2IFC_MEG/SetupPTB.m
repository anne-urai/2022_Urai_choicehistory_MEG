function [window, audio] = SetupPTB(window)

% unify keycodes
KbName('UnifyKeyNames');

% set to higher Priority
%Priority(1);
    
window.screenNum = max(Screen('Screens')); % will use the main screen when single-monitor setup
%window.screenNum = 1; % will use the main screen when single-monitor setup

% get the screen indices for the different colors
window.white=WhiteIndex(window.screenNum);
window.black=BlackIndex(window.screenNum);
window.gray=round((window.white+window.black)/2); %rounding avoids problem with textures

window.bgColor = window.black;

% skip PTB checks
if window.skipChecks,
    Screen('Preference', 'Verbosity', 0);
    Screen('Preference', 'SkipSyncTests', 1);
    Screen('Preference', 'VisualDebugLevel', 0);
    % suppress warnings to the pput window
    Screen('Preference', 'SuppressAllWarnings', 1);
end

window.res = Screen('Resolution',window.screenNum); %enforce 60 Hz

% Open the window
%[window.h, window.rect] =Screen('OpenWindow',window.screenNum,window.bgColor, [0 0 600 600]);
[window.h, window.rect] = Screen('OpenWindow',window.screenNum,window.bgColor);

% find out what happens without the blendfunction?
Screen(window.h,'BlendFunction',GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

% Set the display parameters 'frameRate' and 'resolution'
window.frameDur     = Screen('GetFlipInterval',window.h); %duration of one frame
window.frameRate    = 1/window.frameDur; %Hz
window.slack        = window.frameDur/2; % use the slack when inputting the when argument into Flip

[window.center(1), window.center(2)] = RectCenter(window.rect); % [window.rect(3)/2 window.rect(4)/2];

%% now the audio setup
InitializePsychSound(1);
devices = PsychPortAudio('GetDevices');

% UA-25 is the sound that's played in the subject's earbuds
for i = 1:length(devices)
    if strcmp(devices(i).DeviceName, 'OUT (UA-25)')
        break
    end
end

% check that we found the low-latency audio port
assert(strfind(devices(i).DeviceName, 'UA-25') > 0, 'could not detect the right audio port! aborting')
audio = [];
%i = 10; % for the EEG lab

audio.i = devices(i).DeviceIndex;
audio.freq = devices(i).DefaultSampleRate;
audio.device = devices(i);
audio.h = PsychPortAudio('Open',audio.i,1,1,audio.freq,2);
PsychPortAudio('RunMode',audio.h,1);

HideCursor;
commandwindow;

disp('PTB setup complete');

% Show the subject some instructions
Screen('TextSize', window.h, 20);
Screen('DrawText',window.h, 'Loading the experiment.....', window.center(1)*0.60, window.center(2) , window.black );
Screen('Flip', window.h);

end