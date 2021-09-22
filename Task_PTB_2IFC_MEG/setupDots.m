function [dots] = setupDots(setup, window)

%% design
dots                   = struct; %preallocate

% do some randomization
switch mod(setup.participant, 4),
    case 0
        dots.direction = 45;
    case 1
        dots.direction = 135;
    case 2
        dots.direction = 225;
    case 3
        dots.direction = 315;
end

% appearance of the dots, a la Siegel 2007
dots.radius            = deg2pix(window, 14); %keep constant
dots.innerspace        = deg2pix(window, 2);
dots.lifetime          = setup.nframes; % in frames
dots.nvar              = 3; %interleave 3 variants of the stimulus
dots.color             = [255 255 255]; %  100% dot contrast
dots.speed             = deg2pix(window, 11.5); % speed of the dots in degrees/second
dots.size              = deg2pix(window, 0.2); %size of each dot in degrees
dots.density           = 1.7; % dot density in dots per degree^2
dots.nDots             = round(dots.density*pi*pix2deg(window, dots.radius)^2); %number of dots in the circle, calculated from density (can also just be a fixed nr, eg. 500

end