% Test validation of index counts in long_name and texname

model = modBuilder();

% Test 1: texname has wrong number of indices (should fail)
try
    model.add('Y_$1', 'Y_$1 = alpha_$1', {1, 2});
    model.parameter('alpha_$1', 0.33, 'texname', '\alpha_{$1,$2}', {1, 2});
    error('Expected error: texname has 2 indices but parameter name has 1 index');
catch ME
    if ~contains(ME.message, 'texname has 2 indices')
        rethrow(ME);
    end
    fprintf('Test 1 passed: texname validation works\n');
end

% Test 2: long_name has wrong number of indices (should fail)
model = modBuilder();
try
    model.add('Y_$1_$2', 'Y_$1_$2 = alpha_$1', {'FR', 'DE'}, {1, 2});
    model.parameter('alpha_$1', 0.33, 'long_name', 'Parameter $1 in sector $2', {1, 2});
    error('Expected error: long_name has 2 indices but parameter name has 1 index');
catch ME
    if ~contains(ME.message, 'long_name has 2 indices')
        rethrow(ME);
    end
    fprintf('Test 2 passed: long_name validation works\n');
end

% Test 3: Correct number of indices (should succeed)
model = modBuilder();
model.add('Y_$1_$2', 'Y_$1_$2 = rho_$1_$2*K_$1_$2', {'FR', 'DE'}, {1, 2});
model.parameter('rho_$1_$2', 0.9, ...
                'long_name', 'Parameter for $1 sector $2', ...
                'texname', '\rho_{$1,$2}', ...
                {'FR', 'DE'}, {1, 2});
model.exogenous('K_$1_$2', 1.0, ...
                'texname', 'K^{$1}_{$2}', ...
                {'FR', 'DE'}, {1, 2});
fprintf('Test 3 passed: Correct index count works\n');

% Test 4: No indices in texname when symbol has indices (should fail)
model = modBuilder();
try
    model.add('Y_$1', 'Y_$1 = beta_$1', {1, 2});
    model.parameter('beta_$1', 0.5, 'texname', '\beta', {1, 2});
    error('Expected error: texname has 0 indices but parameter name has 1 index');
catch ME
    if ~contains(ME.message, 'texname has 0 indices')
        rethrow(ME);
    end
    fprintf('Test 4 passed: Zero indices in texname correctly detected\n');
end

fprintf('All validation tests passed!\n');
