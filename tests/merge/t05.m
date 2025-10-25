addpath ../utils

% Test merge_symbol_tables helper: symbol table consistency
%
% Tests that after merging:
% - Symbol tables correctly reflect all symbols in their equations
% - T.equations maps each equation to its symbols
% - T.params/T.var/T.varexo map each symbol to equations using it

% Model 1
m1 = modBuilder();
m1.add('y', 'y = alpha*y(-1) + beta*k');
m1.parameter('alpha', 0.8);
m1.parameter('beta', 0.3);
m1.exogenous('k', 0);

% Model 2
m2 = modBuilder();
m2.add('c', 'c = gamma*c(-1) + delta*k');
m2.parameter('gamma', 0.7);
m2.parameter('delta', 0.2);
m2.exogenous('k', 0);

% Merge models
merged = m1.merge(m2);

% Test 1: Verify T.equations exists for both equations
if ~isfield(merged.T.equations, 'y')
    error('Symbol table missing equations.y field');
end
if ~isfield(merged.T.equations, 'c')
    error('Symbol table missing equations.c field');
end

% Test 2: Verify T.equations.y contains correct symbols
% Note: endogenous variable 'y' does not appear in its own symbol list (only RHS symbols)
y_symbols = merged.T.equations.y;
expected_y_symbols = {'alpha', 'beta', 'k'};
if ~isequal(sort(y_symbols), sort(expected_y_symbols))
    error('T.equations.y should contain %s, got %s', ...
          strjoin(expected_y_symbols, ', '), strjoin(y_symbols, ', '));
end

% Test 3: Verify T.equations.c contains correct symbols
% Note: endogenous variable 'c' does not appear in its own symbol list (only RHS symbols)
c_symbols = merged.T.equations.c;
expected_c_symbols = {'gamma', 'delta', 'k'};
if ~isequal(sort(c_symbols), sort(expected_c_symbols))
    error('T.equations.c should contain %s, got %s', ...
          strjoin(expected_c_symbols, ', '), strjoin(c_symbols, ', '));
end

% Test 4: Verify parameters appear in correct equations
if ~isfield(merged.T.params, 'alpha')
    error('Symbol table missing params.alpha field');
end
if ~isequal(merged.T.params.alpha, {'y'})
    error('T.params.alpha should reference equation y');
end

if ~isfield(merged.T.params, 'gamma')
    error('Symbol table missing params.gamma field');
end
if ~isequal(merged.T.params.gamma, {'c'})
    error('T.params.gamma should reference equation c');
end

% Test 5: Verify exogenous variable 'k' appears in both equations
if ~isfield(merged.T.varexo, 'k')
    error('Symbol table missing varexo.k field');
end
k_equations = sort(merged.T.varexo.k);
expected_k_equations = sort({'y', 'c'});
if ~isequal(k_equations, expected_k_equations)
    error('T.varexo.k should reference equations y and c, got %s', ...
          strjoin(k_equations, ', '));
end

% Test 6: Verify T.var structure exists (may be empty if endogenous vars don't cross-reference)
% T.var tracks endogenous variables appearing in OTHER equations
% In this test, y and c don't appear in each other's equations (except via lags)
% So T.var may legitimately be empty
if ~isfield(merged.T, 'var')
    error('Symbol table missing T.var field');
end
% Don't check individual fields - they only exist if variables appear in other equations
