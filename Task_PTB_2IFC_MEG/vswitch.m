function a = vswitch(modenum)

% Init serial
s = serial('COM1');
fopen(s);
set(s,'Baudrate',19200);
% current config of selected serial port
% uncomment if You'd like to see current config of serial interface

% clear buffer
while s.BytesAvailable > 0
    tline = fgets(s);
end
% Init switch command
% modenum = 0;
SwitchCMD = sprintf('profile f%02d load\r',modenum);
fprintf(s,SwitchCMD)
% allow some time
pause on;
pause(1);
% read reply
while s.BytesAvailable > 0
    answer = fgets(s);
end
fclose(s);
a=answer;
