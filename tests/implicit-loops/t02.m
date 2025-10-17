model = modBuilder();

Countries = {'FR', 'DE', 'IT', 'BE'};
Sectors = num2cell(1:10);

model.add('Y_$1_$2', 'Y_$1_$2 = A_$1*K_$1_$2^alpha_$2*L_$1_$2^(1-alpha_$2)', Countries, Sectors);

model.parameter('alpha_$1', 1/3, Sectors);

if ~isequal(transpose(model.params(:,1)), strcat('alpha_', cellfun(@num2str, Sectors, 'UniformOutput', false)))
    error('Parameter names with indices not created properly.')
end

if ~all(cellfun(@(x) isequal(x, 1/3), model.params(:,2)))
    error('Parameter values with indices not assigned properly.')
end

model.exogenous('A_$1', 1.0, Countries);
model.exogenous('K_$1_$2', 1.0, Countries, Sectors);
model.exogenous('L_$1_$2', 0.5, Countries, Sectors);

if ~isequal(size(model.varexo,1), 84)
    error('Exogenous variables with indices not created properly (wrong number of exogenous variables).')
end

if ~isequal(model.varexo(:,1)', [strcat('A_', Countries), ...
                                    strcat('K_FR_', cellfun(@num2str, Sectors, 'UniformOutput', false)), ...
                                    strcat('K_DE_', cellfun(@num2str, Sectors, 'UniformOutput', false)), ...
                                    strcat('K_IT_', cellfun(@num2str, Sectors, 'UniformOutput', false)), ...
                                    strcat('K_BE_', cellfun(@num2str, Sectors, 'UniformOutput', false)), ...
                                    strcat('L_FR_', cellfun(@num2str, Sectors, 'UniformOutput', false)), ...
                                    strcat('L_DE_', cellfun(@num2str, Sectors, 'UniformOutput', false)), ...
                                    strcat('L_IT_', cellfun(@num2str, Sectors, 'UniformOutput', false)), ...
                                    strcat('L_BE_', cellfun(@num2str, Sectors, 'UniformOutput', false))])
    error('Exogenous variables with indices not created properly (wrong names).')
end

values = model.varexo(:,2);
expected_values = num2cell([repmat(1.0, length(Countries)+length(Countries)*length(Sectors), 1); repmat(0.5, length(Countries)*length(Sectors), 1)]);

if ~isequal(values, expected_values)
    error('Exogenous variable values with indices not assigned properly.')
end