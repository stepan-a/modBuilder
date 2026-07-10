% STEADY_STATE(expression) end-to-end through the modBuilder API.
%
% Regression for the reported bug: an equation carrying STEADY_STATE of an
% expression (not just a bare symbol) -- valid per the Dynare reference manual
% -- must build, expose its inner symbols, and round-trip through write() the
% same way a mod file loaded from Dynare would reparse it.

m = modBuilder();
% Gap variable defined against a steady-state ratio expression.
m.add('gap', 'gap = y/c - STEADY_STATE(y/c)');
m.add('y', 'y = a*k^alpha');
m.add('k', 'k = i + (1-delta)*k(-1)');
m.add('c', 'c = y - i');
m.parameter('alpha', 0.3);
m.parameter('delta', 0.025);
m.exogenous('a', 1);
m.exogenous('i', 0.2);

% The equation is stored verbatim and the STEADY_STATE argument survives.
eq = m.equations{strcmp(m.equations(:,1), 'gap'), 2};
assert(contains(eq, 'STEADY_STATE(y/c)'), 'STEADY_STATE expression preserved in the equation');

% The residual parses as an ast (this is the exact step that failed on load:
% the loader splits on '=' and parses "(LHS) - (RHS)"), and the symbols inside
% STEADY_STATE(y/c) are recognised as references (y, c).
parts = strsplit(eq, '=');
residual = ast(sprintf('(%s) - (%s)', strtrim(parts{1}), strtrim(parts{2}))).staticise().simplify();
assert(~isempty(residual), 'equation residual parses to an ast');
syms = residual.symbol_names();
assert(ismember('y', syms) && ismember('c', syms), 'inner symbols referenced');
assert(~ismember('STEADY_STATE', syms), 'STEADY_STATE is not itself a symbol');

% write() round-trips the model, STEADY_STATE expression intact.
base = tempname;
m.write(base);
cleanup = onCleanup(@() delete([base '.mod']));
txt = fileread([base '.mod']);
assert(contains(txt, 'STEADY_STATE(y/c)') || contains(txt, 'STEADY_STATE(y / c)'), ...
    'written .mod keeps the STEADY_STATE expression');

fprintf('ss-expr/t01: STEADY_STATE(expression) builds, references its symbols, and round-trips\n');
