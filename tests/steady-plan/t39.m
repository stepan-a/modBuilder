% apply_steady_plan(GenerateHelpers=true): blocks without a symbolic closed form
% become generated MATLAB routines called from the steady_state_model block, so the
% steady state stays analytical CONDITIONALLY on small numerical systems (the
% multi-country / multi-sector situation).
%
% The model has an analytic prologue (z), a nonlinear singleton (q), a pair {a, b}
% that elimination only closes partially, and an analytic epilogue (y).

m = build_t39_model();

cleanup = onCleanup(@() cellfun(@delete_if_exists, {'t39m.mod', 't39m_ssblock_2.m', 't39m_ssblock_3.m', 't39d_ssblock_2.m', 't39d_ssblock_3.m'}));

pl = m.steady_plan(Match=true);
m.apply_steady_plan(pl, GenerateHelpers=true, Basename='t39m');

assert(exist('t39m_ssblock_2.m', 'file') == 2, 'the nonlinear singleton q must get a generated routine');
assert(exist('t39m_ssblock_3.m', 'file') == 2, 'the pair {a, b} must get a generated routine');

lastwarn('');
m.write('t39m', steady_state_model=true);
[~, id] = lastwarn();
assert(~strcmp(id, 'modBuilder:write:incompleteSteadyStateModel'), 'with helpers the steady_state_model block must be complete');
mod = fileread('t39m.mod');
assert(contains(mod, 'b = t39m_ssblock_3('), 'the pair reduces by elimination: only b is solved numerically');
assert(contains(mod, 'a = '), 'a must come out as a conditional closed form after the call');
assert(contains(mod, 'q = t39m_ssblock_2('), 'the singleton call must be a plain assignment');

% Execute the emitted cascade (scalar rows and block calls, in checksteady order)
% and verify every model equation at the recovered point.
rho = 0.5; qbar = 2; ez = 0; %#ok<NASGU>
rehash;
[~, sorted_rows] = m.checksteady();
for i = 1:numel(sorted_rows)
    nm = m.steady_state{sorted_rows(i), 1};
    expr = m.steady_state{sorted_rows(i), 2};
    if ischar(nm)
        eval([nm ' = ' expr ';']);
    else
        eval(['[' strjoin(nm, ', ') '] = ' expr ';']);
    end
end
assert(abs(log(z) - rho*log(z) - ez) < 1e-9,  'z equation must hold');
assert(abs(log(q) + q - z - qbar) < 1e-9,     'q equation must hold');
assert(abs(a - exp(-b) - q) < 1e-9,           'a equation must hold');
assert(abs(b + log(b) - 3*a) < 1e-9,          'b equation must hold');
assert(abs(y - a*b - z) < 1e-9,               'y equation must hold');

% Solver='dynare' delegates to dynare_solve (fsolve reachable via SolveAlgo=0);
% content check only, execution needs a Dynare session.
md = build_t39_model();
md.apply_steady_plan(pl, GenerateHelpers=true, Basename='t39d', Solver='dynare', SolveAlgo=0);
helper = fileread('t39d_ssblock_3.m');
assert(contains(helper, 'dynare_solve('),      'the dynare variant must delegate to dynare_solve');
assert(contains(helper, 'opts.solve_algo = 0'), 'SolveAlgo must be forced in the generated helper');
assert(contains(helper, 'opts.jacobian_flag = true'), 'the analytic Jacobian must be advertised to dynare_solve');

% Without helpers the partial steady_state_model block must be flagged at write time.
mp = build_t39_model();
mp.apply_steady_plan(pl);
lastwarn('');
mp.write('t39m', steady_state_model=true);
[~, id] = lastwarn();
assert(strcmp(id, 'modBuilder:write:incompleteSteadyStateModel'), 'a partial steady_state_model block must raise the completeness warning');

fprintf('steady-plan/t39: open blocks close through generated routines in steady_state_model\n');

function m = build_t39_model()
    m = modBuilder();
    m.add('z', 'log(z) - rho*log(z(-1)) - ez');
    m.add('q', 'log(q) + q - z - qbar');
    m.add('a', 'a - exp(-b) - q');
    m.add('b', 'b + log(b) - 3*a');
    m.add('y', 'y - a*b - z');
    m.parameter('rho', 0.5);
    m.parameter('qbar', 2);
    m.exogenous('ez', 0);
    m.endogenous('q', 1.5);
    m.endogenous('a', 2);
    m.endogenous('b', 5);
end

function delete_if_exists(f)
    if exist(f, 'file') == 2
        delete(f);
    end
end
