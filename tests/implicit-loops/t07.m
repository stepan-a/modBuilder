% Test implicit loops for remove method

% Test 1: Simple implicit loop with single index - remove subset
model = modBuilder();
Sectors = num2cell(1:5);
model.add('Y_$1', 'Y_$1 = A_$1*K_$1', Sectors);
model.parameter('A_$1', 1.0, Sectors);
model.exogenous('K_$1', 1.0, Sectors);

if ~isequal(model.size('endogenous'), 5)
    error('Initial setup: should have 5 endogenous variables');
end

% Remove Y_2, Y_3, Y_4 using implicit loop
model.remove('Y_$1', {2, 3, 4});

if ~isequal(model.size('endogenous'), 2)
    error('After remove: should have 2 endogenous variables remaining');
end

% Check that Y_1 and Y_5 remain
remaining_eqs = model.equations(:,1);
if ~any(strcmp(remaining_eqs, 'Y_1'))
    error('Y_1 should remain after remove');
end
if ~any(strcmp(remaining_eqs, 'Y_5'))
    error('Y_5 should remain after remove');
end

% Check that Y_2, Y_3, Y_4 were removed
if any(strcmp(remaining_eqs, 'Y_2')) || any(strcmp(remaining_eqs, 'Y_3')) || any(strcmp(remaining_eqs, 'Y_4'))
    error('Y_2, Y_3, Y_4 should be removed');
end

fprintf('Test 1 passed: Simple implicit loop with single index\n');

% Test 2: Multiple indices - remove subset
model = modBuilder();
Countries = {'FR', 'DE', 'IT'};
Sectors = num2cell(1:3);
model.add('Y_$1_$2', 'Y_$1_$2 = A_$1_$2*K_$1_$2', Countries, Sectors);
model.parameter('A_$1_$2', 1.0, Countries, Sectors);
model.exogenous('K_$1_$2', 1.0, Countries, Sectors);

if ~isequal(model.size('endogenous'), 9)  % 3 countries × 3 sectors
    error('Initial setup: should have 9 endogenous variables');
end

% Remove all French and German sector 1 and 2 equations
model.remove('Y_$1_$2', {'FR', 'DE'}, {1, 2});

if ~isequal(model.size('endogenous'), 5)  % 9 - 4 = 5 remaining
    error('After remove: should have 5 endogenous variables remaining');
end

% Check that IT equations remain
remaining_eqs = model.equations(:,1);
if ~any(strcmp(remaining_eqs, 'Y_IT_1'))
    error('Y_IT_1 should remain');
end
if ~any(strcmp(remaining_eqs, 'Y_IT_2'))
    error('Y_IT_2 should remain');
end
if ~any(strcmp(remaining_eqs, 'Y_IT_3'))
    error('Y_IT_3 should remain');
end

% Check that FR and DE sector 3 remain
if ~any(strcmp(remaining_eqs, 'Y_FR_3'))
    error('Y_FR_3 should remain');
end
if ~any(strcmp(remaining_eqs, 'Y_DE_3'))
    error('Y_DE_3 should remain');
end

% Check that removed equations are gone
if any(strcmp(remaining_eqs, 'Y_FR_1')) || any(strcmp(remaining_eqs, 'Y_FR_2'))
    error('Y_FR_1 and Y_FR_2 should be removed');
end
if any(strcmp(remaining_eqs, 'Y_DE_1')) || any(strcmp(remaining_eqs, 'Y_DE_2'))
    error('Y_DE_1 and Y_DE_2 should be removed');
end

fprintf('Test 2 passed: Multiple indices - remove subset\n');

% Test 3: Remove all with implicit loop
model = modBuilder();
Countries = {'FR', 'DE'};
model.add('C_$1', 'C_$1 = Y_$1 - I_$1', Countries);
model.exogenous('Y_$1', 1.0, Countries);
model.exogenous('I_$1', 0.2, Countries);

if ~isequal(model.size('endogenous'), 2)
    error('Initial setup: should have 2 endogenous variables');
end

% Remove all consumption equations
model.remove('C_$1', Countries);

if ~isequal(model.size('endogenous'), 0)
    error('After remove all: should have 0 endogenous variables');
end

fprintf('Test 3 passed: Remove all with implicit loop\n');

% Test 4: Verify error handling for wrong number of indices
model = modBuilder();
model.add('Y_$1_$2', 'Y_$1_$2 = A_$1_$2', {'FR', 'DE'}, {1, 2});
model.parameter('A_$1_$2', 1.0, {'FR', 'DE'}, {1, 2});

try
    % Try to remove with wrong number of index arrays (should have 2, providing 1)
    model.remove('Y_$1_$2', {'FR'});
    error('Should have thrown an error for wrong number of indices');
catch ME
    if ~contains(ME.message, 'number of indices')
        rethrow(ME);
    end
    fprintf('Test 4 passed: Error handling for wrong number of indices\n');
end

% Test 5: String indices
model = modBuilder();
Countries = {'FR', 'DE', 'IT', 'ES'};
model.add('GDP_$1', 'GDP_$1 = C_$1 + I_$1', Countries);
model.exogenous('C_$1', 1.0, Countries);
model.exogenous('I_$1', 0.3, Countries);

if ~isequal(model.size('endogenous'), 4)
    error('Initial setup: should have 4 endogenous variables');
end

% Remove French and Spanish GDP
model.remove('GDP_$1', {'FR', 'ES'});

if ~isequal(model.size('endogenous'), 2)
    error('After remove: should have 2 endogenous variables remaining');
end

remaining_eqs = model.equations(:,1);
if ~any(strcmp(remaining_eqs, 'GDP_DE')) || ~any(strcmp(remaining_eqs, 'GDP_IT'))
    error('GDP_DE and GDP_IT should remain');
end
if any(strcmp(remaining_eqs, 'GDP_FR')) || any(strcmp(remaining_eqs, 'GDP_ES'))
    error('GDP_FR and GDP_ES should be removed');
end

fprintf('Test 5 passed: String indices\n');

fprintf('All remove implicit loop tests passed!\n');
