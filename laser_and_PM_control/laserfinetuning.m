function reply = laserfinetuning(s,ftf)

if ftf < 0
    ftfint16 = 65536+ftf;
else
    ftfint16 = ftf;
end

reply = ITLAcommand(s,0x62,ftfint16,1);

end