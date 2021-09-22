function [ window ] = drawSquares( window )
% draw squares in the cornes of the screen to be able to reposition the
% screen correctly

% red squares in the corner to position the screen
Screen('FillRect', window.h, window.white, [window.res.width-50 window.res.height-50 window.res.width window.res.height]); % right bottom corner
Screen('FillRect', window.h, window.white, [window.res.width-50 0 window.res.width 50]); %top right corner
Screen('FillRect', window.h, window.white, [0 window.res.height-50 50 window.res.height]); % left bottom corner
Screen('FillRect', window.h, window.white, [0 0 50 50]); % left top corner
Screen('FillRect', window.h, window.white, [window.center(1)-10 window.res.height-50 window.center(1)+10 window.res.height]);
Screen('FillRect', window.h, window.white, [window.center(1)-10 0 window.center(1)+10 50]);

end

