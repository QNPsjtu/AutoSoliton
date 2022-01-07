% search for soliton state automatically

% cavity:       chip = A1   FSR = 100GHz    gap = 0.45
% pump laser: ~1552.4nm     ~30dBm      max-power mode
% aux. laser: ~1557.1nm     ~32dBm      min-power mode

%% connection

addpath("EDFA_BGpkg","laser_and_PM_control")

% clear
serialportlist("all")

if ~exist('PPCL300','var')
    PPCL300 = serialport("COM7",9600)
end
if ~exist('PPCL550','var')
    PPCL550 = serialport("COM13",9600)
end
if ~exist('PM','var')
    PM = serialport("COM1",115200)
end
% if ~exist('EDFApump','var')
%     EDFApump = serialport("COM3",9600)
% end
if ~exist('EDFAaux','var')
    EDFAaux = serialport("COM5",9600)
end



%% initialization of PPCL300, PPCL550

% confirm connection and shut down the laser if it is on. display device
% info. running mode. power and frequency are also initialized.
errflaglaser300 = laserinit(PPCL300)
errflaglaser550 = laserinit(PPCL550)

% set output power to the 6dBm
reply = ITLAcommand(PPCL300,0x31,600,1);
reply = ITLAcommand(PPCL550,0x31,600,1);

% set PPCL300 frequency to near 1557.1nm
reply = ITLAcommand(PPCL300,0x35,192,1);    %%%
reply = ITLAcommand(PPCL300,0x36,5430,1);   %%%

% set PPCL550 frequency to near 1552.4nm
reply = ITLAcommand(PPCL550,0x35,193,1);    %%%
reply = ITLAcommand(PPCL550,0x36,1430,1);   %%%


%% initialization of PM

% set PM wavelength to 1550nm
errflagPM = PMinit(PM)

% set sample rate of PM to 1Ksps
[datareply,cmdreply] = PMcommand(PM,0x01,[0x04,0x38],[0x01,0x05]);
[datareply,cmdreply] = PMcommand(PM,0x01,[0x04,0x38],[0x02,0x05]);
[datareply,cmdreply] = PMcommand(PM,0x01,[0x04,0x38],[0x03,0x05]);

%% initialization of EDFApump

Poutpump=31;
% Poutpump=25;
[reply,op_mode] = EDFA_BG_set_op_mode_APC(EDFApump,Poutpump);
[reply,state] = EDFA_BG_open(EDFApump);
display(state)


%% initialization of EDFAaux

Poutaux=20;
[reply,op_mode] = EDFA_BG_set_op_mode_APC(EDFAaux,Poutaux);
[reply,state] = EDFA_BG_open(EDFAaux);
display(state)


%% PPCL550 on for coupling

% PPCL550 laser output
reply = ITLAcommand(PPCL550,0x32,8,1);
tic
while true
    reply = ITLAcommand(PPCL550,0,0,0);
    if reply(3) == 0
        break
    else
        pause(2)
    end
end
toc

disp('PPCL550 ready')


%% PM on for coupling

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%               COUPLING
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

powermeter


%% PPCL300 on

% PPCL300 laser output
reply = ITLAcommand(PPCL300,0x32,8,1);
tic
while true
    reply = ITLAcommand(PPCL300,0,0,0);
    if reply(3) == 0
        break
    else
        pause(2)
    end
end
toc

disp('PPCL300 ready')


%% FPC

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%               FPC
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

powermeter


%% aux. laser PPCL300

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PPCL300 fine tuning -14000 %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% turn on no-dither mode
reply = ITLAcommand(PPCL300,0x90,1,1);
pause(1)
% set clean sweep range to 60GHz
cleansweeprange300 = 60; % [GHz]        %%%
reply = ITLAcommand(PPCL300,0xE4,cleansweeprange300,1);
% set scan speed to 4000MHz/s
cleansweepspeed300 = 4000; % [MHz/s]    %%%
reply = ITLAcommand(PPCL300,0xF1,cleansweepspeed300,1);
% turn on clean sweep
reply = ITLAcommand(PPCL300,0xE5,1,1);

% skip the sweeping range of inceasing frequency
while true
    
    pause(1)
    reply = ITLAcommand(PPCL300,0xE6,0,0);
    foffset300 = uint8toint16(reply(3),reply(4))/10
    if foffset300 < 0
        disp('PPCL300 start decreasing frequency')
        break
    end
end

% create variable to store power measurement data
powerstorelen = 2^10;
powerstore = zeros(1,powerstorelen);
powerptr = 1; % pointer
transpectrum300 = [];

% discard all messages before PM is turned on
if PM.NumBytesAvailable > 0
    PM.read(PM.NumBytesAvailable,"uint8");
end
pause(0.010)
% PM continuous measurement on
PM.write([0x7B,0x01,0x06,0x01,0x4A,0x02,0x31,0x7D],"uint8");

exeflag = false;
runningflag = true;
while runningflag
    
    % PM read
    [PMstate,powerstore,powerptr] = PMreadpower(PM,powerstore,powerptr);
    if PMstate == -1
        runningflag = false;
        continue
    elseif PMstate == 0
        pause(0.001)
        continue
    elseif PMstate == 2
        exeflag = true;
    end
    
    % record transmission spectrum
    if exeflag == true
        exeflag = false;
        powerseq = [powerstore(powerptr+1:end),powerstore(1:powerptr)];
        transpectrum300 = [transpectrum300;powerseq];
    end
    
    % if the range is covered, stop sweeping
    reply = ITLAcommand(PPCL300,0xE6,0,0);
    foffset300 = uint8toint16(reply(3),reply(4))/10;
    if foffset300 < -cleansweeprange300/2
        runningflag = false;
    end
    
end

% PM continuous measurement off
PM.write([0x7B,0x01,0x06,0x01,0x4A,0x00,0x33,0x7D],"uint8");
% discard all messages after PM is turned off
if PM.NumBytesAvailable > 0
    PM.read(PM.NumBytesAvailable,"uint8");
end

% turn off clean sweep
reply = ITLAcommand(PPCL300,0xE5,0,1); % turn off clean sweep
reply = ITLAcommand(PPCL300,0x90,0,1); % turn to standard mode
pause(5)

% transmission spectrum
transpectrum300 = transpectrum300.';
transpectrum300 = transpectrum300(:);

% find resonance
[freqoffset300,debug01] = auxpump_freq_offset(transpectrum300,cleansweeprange300/2*1000);

% plot the transmission spectrum of aux. pump
figure(201)
yyaxis left
plot(debug01)
yyaxis right
plot(transpectrum300)
ylabel('dBm')
grid minor
pause(0.100)


% fine tune aux. laser
laserftf300 = -floor(freqoffset300) + 18000;
reply = laserfinetuning(PPCL300,laserftf300);
pause(abs(laserftf300)/900);
laserftf300 = -floor(freqoffset300) + 6000;
reply = laserfinetuning(PPCL300,laserftf300);
pause((18000-6000)/900);

auxpumpdetuning = 9500;
laserftf300 = -floor(freqoffset300) + auxpumpdetuning;
reply = laserfinetuning(PPCL300,laserftf300);

pause(abs(6000-auxpumpdetuning)/900)

disp('aux. laser frequency offset:');disp(laserftf300)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% HEATING THE CHIP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% pump laser PPCL550


% noise
pause(10)
[powernoise_f,~] = PMpowermeanstdmW(PM,3,50);
disp('noise power:');disp(powernoise_f)
% soliton searching
solitonstate = 0;
solitonflag = false;
maxrevivenum = 1;
revivenum = 0;
while true
    switch solitonstate
        case 0
            laserftf550 = 0;
            solitonstate = 1;
        case 1
            % TODO: if FBG is not compatible
            solitonstate = 2;
        case 2
            % if pump is far from the resonance
            if PMpowermeanmW(PM,3,10) < powernoise_f + 0.4
                laserftf550 = laserftf550 - 80;
                laserfinetuning(PPCL550,laserftf550);
                pause(0.400)
            else
                solitonstate = 3;
            end
        case 3
            % chaotic
            if PMpowerstdmW(PM,3,10) > 0.020    %%%
                laserftf550 = laserftf550 - 50;
                laserfinetuning(PPCL550,laserftf550);
                pause(0.400)
            else
                solitonstate = 4;
            end
        case 4
            % go over the resonance peak
            if PMpowermeanmW(PM,3,10) > powernoise_f + 3*0.15
                laserftf550 = laserftf550 - 20;
                laserfinetuning(PPCL550,laserftf550);
                pause(0.200)
            else
                solitonstate = 5;
            end
        case 5
            % prepare for searching for single soliton
            pause(0.100)
            powerprevious = PMpowermeanmW(PM,3,5);
            powernext = powerprevious;
            solitonstate = 6;
        case 6
            % search for single soliton
            powernext = PMpowermeanmW(PM,3,5);
            if powerprevious - powernext > 0.05
                % if power suddenly drops
                disp('--STEP--')
                powerdropratio =...
                    (powerprevious-powernext)/(powerprevious-powernoise_f);
                disp('power drop ratio:');disp(powerdropratio)
                if powerdropratio > 0.80 && powernext < powernoise_f + 0.15
                    solitonstate = 10;
                elseif powerdropratio > 0.5-0.1 && powernext > powernoise_f
                    disp('soliton detected at:');disp(laserftf550)
                    disp('soliton power:');disp(powernext)
                    solitonstate = 7;
                end
            end
            powerprevious = powernext;
            laserftf550 = laserftf550 - 10;
            reply = laserfinetuning(PPCL550,laserftf550);
            pause(0.100)
        case 7
            % prepare for stabilizing soliton
            laserftf550 = laserftf550 + 100;
            reply = laserfinetuning(PPCL550,laserftf550);
            powerprevious = powernext;
            solitonstate = 8;
            solitonflag = true;
            tic
        case 8
            % stabilize soliton
            powernext = PMpowermeanmW(PM,3,5);
            powerdropratio =...
                (powerprevious-powernext)/(powerprevious-powernoise_f);
            if powerdropratio > 0.75
                solitonflag = false;
                solitonstate = 10;
                disp('duration');disp(toc)
            else
                powerprevious = powernext;
                pause(1)
            end
        case 10
            % soliton gone
            disp('SOLITON GONE')
            laserftf550 = laserftf550 - 500;
            pause(500/200);
            powernoise_f2 = PMpowermeanmW(PM,3,5);
            if abs(powernoise_f2-powernoise_f)/powernoise_f > 0.50
                disp('WARNING: aux. pump misplaced')
                pause(5)
            end
            powernoise_f = powernoise_f2;
            disp('noise power:');disp(powernoise_f)
            if revivenum >= maxrevivenum
                break
            else
                revivenum = revivenum + 1;
                laserftf550 = laserftf550 + 1600;
                reply = laserfinetuning(PPCL550,laserftf550);
                pause(1600/250)
                solitonstate = 0;
            end
    end
    
    if abs(laserftf550) > 30000
        disp('ftf error')
        break
    end
    if solitonflag == false
        disp('soliton state');disp(solitonstate)
    end
    
end


%%

Poutpump=31;
[reply,Pout_set_return] = EDFA_BG_set_APC_Pout(EDFApump,Poutpump)

%% 
[reply,state] = EDFA_BG_close(EDFApump);
display(state)

%%

[reply,state] = EDFA_BG_close(EDFAaux);
display(state)

%%

[~,temppump] = EDFA_BG_read_temp(EDFApump)
[~,tempaux] = EDFA_BG_read_temp(EDFAaux)

%% all devices turned off

% shut down PPCL300
reply = ITLAcommand(PPCL300,0x32,0,1)
% shut down PPCL550
reply = ITLAcommand(PPCL550,0x32,0,1)




%%

function pmmW = PMpowermeanmW(s,ch,n)

p = zeros(1,n);
for idx = 1:n
    ptmp = PMreadpowerRIS(s,ch);
    p(idx) = 10^(ptmp/10);
end

pmmW = mean(p);

end

function pstdmW = PMpowerstdmW(s,ch,n)

p = zeros(1,n);
for idx = 1:n
    ptmp = PMreadpowerRIS(s,ch);
    p(idx) = 10^(ptmp/10);
end

pstdmW = std(p);

end



