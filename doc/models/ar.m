function eq = ar(maxlag, ename, pname, xname)
    eq = sprintf('%s =', ename);
    for l=1:maxlag
        eq = sprintf('%s %s%u*%s(-%u) +', eq, pname, l, ename, l);
    end
    eq = sprintf('%s %s', eq, xname);
end
