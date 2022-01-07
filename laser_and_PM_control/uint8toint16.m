function data16 = uint8toint16(byte1,byte0)

data16 = byte1*256+byte0;
if data16 >= 32768
    data16 = data16-65536;
end

end