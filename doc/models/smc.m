m = modBuilder();

Countries = {'FR' 'IT' 'DE' 'BE'};
Sectors = num2cell(1:10);

m.add('Y_$1_$2', 'Y_$1_$2 = A_$1*K_$1_$2^alpha*L_$1_$2^(1-alpha)', Countries, Sectors);

m.parameter('alpha', 1/3);
for i=1:numel(Countries)
    m.exogenous(sprintf('A_%s', Countries{i}), 1.0);
    for j=1:numel(Sectors)
        m.exogenous(sprintf('K_%s_%u', Countries{i}, Sectors{j}), 1+10*rand);
        m.exogenous(sprintf('L_%s_%u', Countries{i}, Sectors{j}), rand);
    end
end

m.updatesymboltables();

m.Y_FR_1.equations{2}
