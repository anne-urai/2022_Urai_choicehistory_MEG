function trigger = setupTrig(setup)


%% TRIGGERS

% Event                 Value	Pins
% Fixation onset		64	01100100
% Reference onset		48	01001000
% Interval onset		40	01000000
%
% Stimulus - weaker		31	00110001
% Stimulus - stronger   30	00110000
%
% Response - weaker     21	00100001
% Response - stronger	20	00100000
%
% Feedback - correct	11	00010001
% Feedback - incorrect	10	00010000

trigger.address      = hex2dec('378');
trigger.zero         = 0;
trigger.width        = 0.005; %1 ms trigger signal

trigger.fix          = 64; % fixation is 64
trigger.ref          = 48;
trigger.interval     = 40;

trigger.stim        = setup.increment; % copy the weaker-stronger
trigger.stim(trigger.stim == -1)    = 31;
trigger.stim(trigger.stim == 1)     = 30;

trigger.resp.weaker     = 21;
trigger.resp.stronger   = 20;
trigger.resp.correct    = 25;
trigger.resp.incorrect  = 26;
trigger.resp.noresp     = 29;

trigger.feedback.correct    = 11;
trigger.feedback.incorrect  = 10;
trigger.feedback.noresp     = 19;

trigger.blinkbreakstart     = 60;

trigger.beep                = 100;

end
