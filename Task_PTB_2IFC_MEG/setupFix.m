function fix = setupFix(window)

%% fixation
% this is the fixation descibed in Thaler et al.
fix.dotsize         = deg2pix(window,0.15); % fixation dot
fix.circlesize      = deg2pix(window,0.6); % circle around fixation dot
fix.color           = [255 0 0]; %red
end

