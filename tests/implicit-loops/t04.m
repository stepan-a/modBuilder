model = modBuilder();

Sectors = num2cell(1:3);
Countries = {'FR', 'DE'};

% Add equation
model.add('Y_$1_$2', 'Y_$1_$2 = alpha_$2*K_$1_$2', Countries, Sectors);

% Parameters with indexed TeX names
model.parameter('alpha_$1', 1/3, ...
                'long_name', 'Share parameter for sector $1', ...
                'texname', '\alpha_{$1}', ...
                Sectors);

% Exogenous with indexed TeX names
model.exogenous('K_$1_$2', 1.0, ...
                'long_name', 'Capital in $1 sector $2', ...
                'texname', 'K^{$1}_{$2}', ...
                Countries, Sectors);

% Verify parameter TeX names
expected_param_tex = {'\alpha_{1}'; '\alpha_{2}'; '\alpha_{3}'};
if ~isequal(model.params(:,4), expected_param_tex)
    error('Parameter TeX names with indices not expanded properly.');
end

% Verify parameter long names
expected_param_long = {'Share parameter for sector 1';
                       'Share parameter for sector 2';
                       'Share parameter for sector 3'};
if ~isequal(model.params(:,3), expected_param_long)
    error('Parameter long names with indices not expanded properly.');
end

% Verify exogenous TeX names (spot check a few)
idx_K_FR_1 = find(strcmp(model.varexo(:,1), 'K_FR_1'));
if ~strcmp(model.varexo{idx_K_FR_1, 4}, 'K^{FR}_{1}')
    error('Exogenous TeX name for K_FR_1 not correct.');
end

idx_K_DE_3 = find(strcmp(model.varexo(:,1), 'K_DE_3'));
if ~strcmp(model.varexo{idx_K_DE_3, 4}, 'K^{DE}_{3}')
    error('Exogenous TeX name for K_DE_3 not correct.');
end

% Verify exogenous long names (spot check)
idx_K_FR_2 = find(strcmp(model.varexo(:,1), 'K_FR_2'));
if ~strcmp(model.varexo{idx_K_FR_2, 3}, 'Capital in FR sector 2')
    error('Exogenous long name for K_FR_2 not correct.');
end

% Write to file (just to test it works)
model.write('t04');

% Verify the .mod file was created
if ~isfile('t04.mod')
    error('Failed to write t04.mod file.');
end

% Clean up
delete('t04.mod');

fprintf('Test passed: Implicit loops with TeX names work correctly.\n');
