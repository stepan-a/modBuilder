m = modBuilder();

COUNTRIES = {'FR' 'IT' 'DE' 'BE'};

m.add('y_$1', ar(12, 'y_$1', 'rho_$1_', 'e_$1'), COUNTRIES);

for i = 1:numel(COUNTRIES)
    for l=1:12
        m.parameter(sprintf('rho_%s_%u', COUNTRIES{i}, l), 2*rand-1);
    end
    m.exogenous(sprintf('e_%s', COUNTRIES{i}), 0);
end

m.updatesymboltables();

m.y_FR

m.y_FR.equations
