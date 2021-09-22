% add psychtoolbox path
path_ptb = fullfile('C:','Documents and Settings','meg','Desktop', 'Experimente','Hannah','myPTB');
addpath(genpath(path_ptb));

%% now the audio setup
InitializePsychSound(1);
devices = PsychPortAudio('GetDevices');

% UA-25 is the sound that's played in the subject's earbuds
for i = 1:length(devices)
    if strcmp(devices(i).DeviceName, 'UA-25')
        break
    end
end
% check that we found the low-latency audio port
%assert(strcmp(devices(i).DeviceName, 'UA-25'), 'could not detect the right audio port! aborting')
i = 11;
audio = [];
audio.i = devices(i).DeviceIndex;
audio.freq = devices(i).DefaultSampleRate;
audio.device = devices(i);
audio.h = PsychPortAudio('Open',audio.i,1,1,audio.freq,2);
PsychPortAudio('RunMode',audio.h,1);

sound.feedback.correct      = 880; % 150  ms, 880 Hz
sound.feedback.incorrect    = 200; % 150 ms, 200 Hz
sound.stimonset             = 440; % 50 ms, 440 Hz


[sound.tonebuf, sound.tonepos] = CreateAudioBuffer(CreateTone(sound.feedback.correct, 0.150, audio.freq), ...
    CreateTone(sound.feedback.incorrect ,0.150, audio.freq) , ...
    CreateTone(sound.stimonset, 0.050, audio.freq));

PsychPortAudio('FillBuffer', audio.h, sound.tonebuf);

stopplaying = false, while ~stopplaying,         % play reference stimulus onset tone
    PsychPortAudio('SetLoop',audio.h, sound.tonepos(3,1), sound.tonepos(3,2));
    PsychPortAudio('Start', audio.h); %like flip end
    WaitSecs(.5)
end