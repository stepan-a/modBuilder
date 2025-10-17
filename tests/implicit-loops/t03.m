model = modBuilder();

Countries = {'FR', 'DE', 'IT', 'BE'};
Sectors = num2cell(1:10);

model.add('Y_$1_$2', 'Y_$1_$2 = A_$1*K_$1_$2^alpha_$2*L_$1_$2^(1-alpha_$2)', Countries, Sectors);

model.parameter('alpha_$1', Sectors);

if ~isequal(transpose(model.params(:,1)), strcat('alpha_', cellfun(@num2str, Sectors, 'UniformOutput', false)))
    error('Parameter names with indices not created properly.')
end

if ~all(cellfun(@isnan, model.params(:,2)))
    error('Parameter values with indices not assigned properly.')
end

for i=1:numel(Countries)
    model.exogenous(sprintf('A_%s', Countries{i}), 1.0);
    for j=1:numel(Sectors)
        model.exogenous(sprintf('K_%s_%u', Countries{i}, Sectors{j}), 1+10*rand);
        model.exogenous(sprintf('L_%s_%u', Countries{i}, Sectors{j}), rand);
    end
end

model.updatesymboltables()
