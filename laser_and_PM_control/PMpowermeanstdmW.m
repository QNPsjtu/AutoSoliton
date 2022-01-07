function [pmmW,pstdmW] = PMpowermeanstdmW(s,ch,n)

p = zeros(1,n);
for idx = 1:n
    ptmp = PMreadpowerRIS(s,ch);
    p(idx) = 10^(ptmp/10);
end

pmmW = mean(p);
pstdmW = std(p);

end