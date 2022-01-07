function errflag = PMinit(s)
% initialize JW1609C power meter
% initialize all powermeters
% input: serialport object of the PM

errflag = false;

% discard all messages accumulated
if s.NumBytesAvailable > 0
    s.read(s.NumBytesAvailable,"uint8");
end

% check communication
[datareply,cmdreply] = PMcommand(s,0xFF,[0x01,0x40],[]);
if sum(cmdreply==[1,65])<2
    errflag = true;
    disp('communication error')
    return
end

% change wavelength to 1550nm
[datareply,cmdreply] = PMcommand(s,0xFF,[0x01,0x44],[0x01,0x05]);
[datareply,cmdreply] = PMcommand(s,0xFF,[0x01,0x44],[0x02,0x05]);
[datareply,cmdreply] = PMcommand(s,0xFF,[0x01,0x44],[0x03,0x05]);

end
