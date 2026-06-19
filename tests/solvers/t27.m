% Tests for newton_system() error paths

% Non-finite residual: residual_fn = 1/x at x0 = 0 is infinite on the first
% iterate.
threw = false;
try
    solvers.newton_system(@(x) 1./x, @(x) -1./x.^2, 0, 1e-6, 50);
catch e
    threw = strcmp(e.identifier, 'modBuilder:newtonSystem:nonFiniteResidual');
end
assert(threw, 'Expected newtonSystem:nonFiniteResidual for an infinite residual.');

% Non-finite Jacobian: residual is finite at x0 = 0 but the Jacobian 1/x is
% infinite there.
threw = false;
try
    solvers.newton_system(@(x) x - 1, @(x) 1/x, 0, 1e-6, 50);
catch e
    threw = strcmp(e.identifier, 'modBuilder:newtonSystem:nonFiniteJacobian');
end
assert(threw, 'Expected newtonSystem:nonFiniteJacobian for an infinite Jacobian.');

% Line-search failure: a wrong-sign Jacobian makes the Newton step an ascent
% direction, so no backtracking step satisfies the Armijo condition and alpha
% underflows the floor.
threw = false;
try
    solvers.newton_system(@(x) x, @(x) -1, 1, 1e-6, 50);
catch e
    threw = strcmp(e.identifier, 'modBuilder:newtonSystem:lineSearchFailed');
end
assert(threw, 'Expected newtonSystem:lineSearchFailed when the step is not a descent direction.');
