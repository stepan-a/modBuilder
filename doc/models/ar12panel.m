m = modBuilder();

COUNTRIES = ["FRA" "ITA" "GER"];

for c = COUNTRIES
    m.add(sprintf('y_%s', c), ...
          ar(12, sprintf('y_%s', c), ...
             sprintf('rho_%s_', c), ...
             sprintf('e_%s', c)));
end

for c = COUNTRIES
    for l=1:12
        m.parameter(sprintf('rho_%s_%u', c, l), 2*rand-1);
    end
    m.exogenous(sprintf('e_%s', c), 0);
end

m.updatesymboltables();

m('y_FRA')

m('y_FRA').equations
