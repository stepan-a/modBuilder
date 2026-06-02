% modBuilder.symbolic_jacobian — sparse matrix of symbolic partials, cross-checked against the AD jacobian

% A small closed nonlinear system (need not be at its true steady state; we only
% evaluate the Jacobian at the calibration point and compare the two paths).
m = modBuilder();
m.add('y', 'y = k^alpha*h^(1-alpha)');
m.add('k', 'k = s*y + (1-delta)*k(-1)');
m.add('c', 'c = (1-s)*y');
m.add('h', 'h = hbar');
m.parameter('alpha', 0.33);
m.parameter('delta', 0.10);
m.parameter('s',     0.20);
m.parameter('hbar',  0.30);
m.endogenous('y', 1.2);
m.endogenous('k', 3.0);
m.endogenous('c', 0.96);
m.endogenous('h', 0.30);

eqs  = {'y', 'k', 'c', 'h'};
vars = {'y', 'k', 'c', 'h'};

J = m.symbolic_jacobian(eqs, vars);
assert(isequal(size(J), [4, 4]), 'symbolic_jacobian should be 4x4');

% Reference AD Jacobian at the same point.
Jad = full(m.jacobian(eqs, vars));

% Build a value map for every symbol that appears in any partial.
values = struct();
for i = 1:numel(eqs)
    for j = 1:numel(vars)
        g = J{i, j};
        if isempty(g), continue; end
        names = g.symbol_names();
        for s = 1:numel(names)
            values.(names{s}) = m.get_value(names{s});
        end
    end
end

% Cell entries: empty == structural zero (and the AD entry must vanish there);
% non-empty == evaluates to the AD value.
for i = 1:numel(eqs)
    for j = 1:numel(vars)
        g = J{i, j};
        if isempty(g)
            assert(Jad(i, j) == 0, sprintf('J{%d,%d} empty but AD entry is %.12g', i, j, Jad(i, j)));
        else
            val = g.eval(values);
            assert(abs(val - Jad(i, j)) < 1e-9, ...
                   sprintf('J{%d,%d}=%s -> %.12g, AD=%.12g', i, j, g.string(), val, Jad(i, j)));
        end
    end
end

% Spot-check the known sparsity pattern: resid_c = c - (1-s)*y depends only on y and c.
assert( isempty(J{3, 2}), 'resid_c should not depend on k');
assert( isempty(J{3, 4}), 'resid_c should not depend on h');
assert(~isempty(J{3, 1}), 'resid_c should depend on y');
assert(~isempty(J{3, 3}), 'resid_c should depend on c');
assert(ast.ast_equal(J{3, 3}, ast('1')), 'd resid_c / dc = 1');

fprintf('partial/t02.m: modBuilder.symbolic_jacobian OK\n');
