% Comprehensive test for new subsref behavior
addpath ../utils

m = modBuilder();
m.add('cons', 'cons = wage*hours');
m.add('output', 'output = cons + invest');
m.add('invest', 'invest = delta*capital');
m.add('c', 'c = 0.5*y');
m.add('y', 'y = a*c');

m.parameter('wage', 1.5);
m.parameter('delta', 0.1);
m.parameter('a', 2.0);
m.exogenous('hours', 8.0);
m.exogenous('capital', 100);
m.endogenous('c', 10);
m.endogenous('y', 20);

fprintf('=== Testing new subsref behavior ===\n\n');

% Test 1: Extract single equation with parentheses
fprintf('Test 1: Extract single equation with parentheses\n');
try
    sub1 = m('cons');
    fprintf('  m(''cons'') - OK, extracted %d equation(s)\n', sub1.size('endogenous'));
catch e
    fprintf('  m(''cons'') - FAILED: %s\n', e.message);
end

% Test 2: Extract multiple equations with parentheses
fprintf('\nTest 2: Extract multiple equations with parentheses\n');
try
    sub2 = m('cons', 'output');
    fprintf('  m(''cons'', ''output'') - OK, extracted %d equation(s)\n', sub2.size('endogenous'));
catch e
    fprintf('  m(''cons'', ''output'') - FAILED: %s\n', e.message);
end

% Test 3: Get parameter value with dot notation (multi-char)
fprintf('\nTest 3: Get parameter value with dot notation (multi-char)\n');
try
    val = m.wage;
    fprintf('  m.wage = %g - OK\n', val);
    if val ~= 1.5
        fprintf('  WARNING: Expected 1.5, got %g\n', val);
    end
catch e
    fprintf('  m.wage - FAILED: %s\n', e.message);
end

% Test 4: Get parameter value with dot notation (single-char)
fprintf('\nTest 4: Get parameter value with dot notation (single-char)\n');
try
    val = m.a;
    fprintf('  m.a = %g - OK\n', val);
    if val ~= 2.0
        fprintf('  WARNING: Expected 2.0, got %g\n', val);
    end
catch e
    fprintf('  m.a - FAILED: %s\n', e.message);
end

% Test 5: Get exogenous variable value with dot notation
fprintf('\nTest 5: Get exogenous variable value with dot notation\n');
try
    val = m.hours;
    fprintf('  m.hours = %g - OK\n', val);
    if val ~= 8.0
        fprintf('  WARNING: Expected 8.0, got %g\n', val);
    end
catch e
    fprintf('  m.hours - FAILED: %s\n', e.message);
end

% Test 6: Get endogenous variable value with dot notation (multi-char)
fprintf('\nTest 6: Get endogenous variable value with dot notation (multi-char)\n');
try
    val = m.cons;
    fprintf('  m.cons = %g - OK\n', val);
catch e
    fprintf('  m.cons - FAILED: %s\n', e.message);
end

% Test 7: Get endogenous variable value with dot notation (single-char)
fprintf('\nTest 7: Get endogenous variable value with dot notation (single-char)\n');
try
    val = m.c;
    fprintf('  m.c = %g - OK\n', val);
    if val ~= 10
        fprintf('  WARNING: Expected 10, got %g\n', val);
    end
catch e
    fprintf('  m.c - FAILED: %s\n', e.message);
end

% Test 8: Method calls still work
fprintf('\nTest 8: Method calls still work\n');
try
    n = m.size('parameters');
    fprintf('  m.size(''parameters'') = %d - OK\n', n);
    if n ~= 3
        fprintf('  WARNING: Expected 3, got %d\n', n);
    end
catch e
    fprintf('  m.size(''parameters'') - FAILED: %s\n', e.message);
end

% Test 9: Property access still works
fprintf('\nTest 9: Property access still works\n');
try
    p = m.params;
    fprintf('  m.params - OK, got %dx%d cell array\n', size(p,1), size(p,2));
catch e
    fprintf('  m.params - FAILED: %s\n', e.message);
end

% Test 10: Verify parentheses extraction preserves old behavior
fprintf('\nTest 10: Verify parentheses extraction preserves old behavior\n');
try
    sub = m('c');
    if isa(sub, 'modBuilder')
        fprintf('  m(''c'') - OK, returns modBuilder\n');
        if sub.size('endogenous') == 1
            fprintf('  Extracted equation count is correct\n');
        else
            fprintf('  WARNING: Expected 1 equation, got %d\n', sub.size('endogenous'));
        end
    else
        fprintf('  WARNING: m(''c'') returned %s instead of modBuilder\n', class(sub));
    end
catch e
    fprintf('  m(''c'') - FAILED: %s\n', e.message);
end

fprintf('\n=== All tests completed ===\n');
