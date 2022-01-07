function reply = laseroutput(s,outputflag)


if outputflag == 1
    
    reply = ITLAcommand(s,0x32,8,1);
    tic
    while true
        reply = ITLAcommand(s,0,0,0);
        if reply(3) == 0
            break
        else
            pause(2)
        end
    end
    toc
    
    disp('LASER TURNED ON')
    
else
    
    reply = ITLAcommand(s,0x32,0,1);
    disp('LASER TURNED OFF')
    
end

end