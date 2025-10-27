% Test implicit loops for endogenous method

model = modBuilder();

% Test 1: Simple implicit loop with single index
Sectors = num2cell(1:3);
model.add('Y_$1', 'Y_$1 = A_$1*K_$1', Sectors);
model.exogenous('A_$1', 1.0, Sectors);
model.exogenous('K_$1', 1.0, Sectors);

% Set values using implicit loop
model.endogenous('Y_$1', 2.5, Sectors);

if ~isequal(transpose(model.var(:,1)), strcat('Y_', cellfun(@num2str, Sectors, 'UniformOutput', false)))
    error('Endogenous variable names with indices not created properly.');
end

if ~all(cellfun(@(x) isequal(x, 2.5), model.var(:,2)))
    error('Endogenous variable values with indices not assigned properly.');
end

fprintf('Test 1 passed: Simple implicit loop with values\n');

% Test 2: Implicit loops with TeX names and long names
model = modBuilder();
Countries = {'FR', 'DE', 'IT'};
model.add('C_$1', 'C_$1 = Y_$1 - I_$1', Countries);
model.exogenous('I_$1', 0.2, Countries);
model.exogenous('Y_$1', 1.0, Countries);

model.endogenous('C_$1', 0.8, ...
                 'long_name', 'Consumption in $1', ...
                 'texname', 'C^{$1}', ...
                 Countries);

% Verify TeX names
expected_tex = {'C^{FR}'; 'C^{DE}'; 'C^{IT}'};
if ~isequal(model.var(:,4), expected_tex)
    error('Endogenous TeX names with indices not expanded properly.');
end

% Verify long names
expected_long = {'Consumption in FR'; 'Consumption in DE'; 'Consumption in IT'};
if ~isequal(model.var(:,3), expected_long)
    error('Endogenous long names with indices not expanded properly.');
end

fprintf('Test 2 passed: Implicit loops with TeX names and long names\n');

% Test 3: Multiple indices
model = modBuilder();
Countries = {'FR', 'DE'};
Sectors = num2cell(1:2);
model.add('Y_$1_$2', 'Y_$1_$2 = A_$1_$2*K_$1_$2', Countries, Sectors);
model.exogenous('A_$1_$2', 1.0, Countries, Sectors);
model.exogenous('K_$1_$2', 1.0, Countries, Sectors);

model.endogenous('Y_$1_$2', 3.0, ...
                 'long_name', 'Output for $1 sector $2', ...
                 'texname', 'Y_{$1,$2}', ...
                 Countries, Sectors);

% Check number of endogenous variables
if ~isequal(size(model.var, 1), 4)
    error('Wrong number of endogenous variables with multiple indices.');
end

% Check specific values
idx_Y_FR_1 = find(strcmp(model.var(:,1), 'Y_FR_1'));
if isempty(idx_Y_FR_1) || model.var{idx_Y_FR_1, 2} ~= 3.0
    error('Endogenous variable Y_FR_1 not set properly.');
end

% Check TeX names
if ~strcmp(model.var{idx_Y_FR_1, 4}, 'Y_{FR,1}')
    error('Endogenous TeX name for Y_FR_1 not correct.');
end

% Check long names
idx_Y_DE_2 = find(strcmp(model.var(:,1), 'Y_DE_2'));
if ~strcmp(model.var{idx_Y_DE_2, 3}, 'Output for DE sector 2')
    error('Endogenous long name for Y_DE_2 not correct.');
end

fprintf('Test 3 passed: Multiple indices with TeX formatting\n');

% Test 4: Implicit loops without value (existing values preserved)
model = modBuilder();
model.add('Z_$1', 'Z_$1 = X_$1', {1, 2});
model.exogenous('X_$1', 0.5, {1, 2});

% First set some values
model.endogenous('Z_1', 10);
model.endogenous('Z_2', 20);

% Now use implicit loop to set TeX names without changing values
model.endogenous('Z_$1', [], 'texname', 'Z_{$1}', {1, 2});

% Check that values are preserved
idx_Z_1 = find(strcmp(model.var(:,1), 'Z_1'));
idx_Z_2 = find(strcmp(model.var(:,1), 'Z_2'));

if model.var{idx_Z_1, 2} ~= 10
    error('Endogenous variable Z_1 value not preserved.');
end

if model.var{idx_Z_2, 2} ~= 20
    error('Endogenous variable Z_2 value not preserved.');
end

% Check TeX names were set
if ~strcmp(model.var{idx_Z_1, 4}, 'Z_{1}')
    error('Endogenous TeX name for Z_1 not set.');
end

fprintf('Test 4 passed: Implicit loops without value (preserves existing values)\n');

% Test 5: Implicit loops without pre-existing values (should set NaN)
model = modBuilder();
model.add('W_$1', 'W_$1 = V_$1', {1, 2});
model.exogenous('V_$1', 1.0, {1, 2});

% Set TeX names without values
model.endogenous('W_$1', [], 'texname', 'W_{$1}', {1, 2});

% Check that values are NaN
idx_W_1 = find(strcmp(model.var(:,1), 'W_1'));
if ~isnan(model.var{idx_W_1, 2})
    error('Endogenous variable W_1 should have NaN value.');
end

fprintf('Test 5 passed: Implicit loops without value (sets NaN for new variables)\n');

fprintf('All endogenous implicit loop tests passed!\n');
