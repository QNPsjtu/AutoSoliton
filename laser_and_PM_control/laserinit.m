function errflag = laserinit(s)
% initialize PPCL300 or PPCL500 
% input: serialport object of the laser


errflag = false;

% check communication by raeding NOP (0x00) register
ITLAcommand(s,0,0,0);
if sum(ITLAcommand(s,0,0,0)==[84,0,0,16])<4
    % if the reply is not [84,0,0,16]
    errflag = true;
    disp('communication error')
    return
end

% shut down the laser
reply = ITLAcommand(s,0x32,0,1);

% display laser type and manufacturer by reading DevTyp (0x01) and MFGR
% (0x02) register
disp(['Device Type: ',char(ITLAcommand(s,1,0,0))]);
disp(['Manufacturer: ',char(ITLAcommand(s,2,0,0))]);

% set output power to 6dBm
reply = ITLAcommand(s,0x31,600,1);

% set channel 1 frequency near 1550nm (193.414THz)
reply = ITLAcommand(s,0x35,193,1);
reply = ITLAcommand(s,0x36,4140,1);

% set output channel as channel 1
reply = ITLAcommand(s,0x30,1,1);

% standard mode (dither mode) output
reply = ITLAcommand(s,0x90,0,1);


end