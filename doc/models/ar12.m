m = modBuilder();
m.add('y', ar(12, 'y', 'rho', 'e'));

for lag = 1:12;
    m.parameter(sprintf('rho%u', lag), 2*rand-1)
end

m.exogenous('e', 0);

m.updatesymboltables();
