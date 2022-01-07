% a simple power meter based on JW1609C

if ~exist('PM','var')
    PM = serialport("COM6",115200)
end

errflagPM = PMinit(PM)

figure(111)
PMterminatorfig = gcf;
title("press Q to close the powermeter")
pause(0.001)

while true
    powerch_all = PMreadpowerRIS(PM,9);
    disp(powerch_all)
    
    if PMterminatorfig.CurrentCharacter == 'Q'
        break
    end    
    pause(0.2)
    
end

disp("power meter closed")
close(PMterminatorfig)