% steady_plan: an ENDOGENOUS unit root is flagged at the pairing -- the classic
% incomplete-markets open economy, where the static Euler condition reduces to
% 1 - beta*R = 0 (consumption factors out entirely) so no equation pins the level
% of net foreign assets.
%
% The bipartite matcher correctly leaves the Euler equation unmatched (no admissible
% candidate: b is absent, c cancels through the c^(-sig) factor); the completion pass
% force-pairs it to keep the plan square and must warn that the level is free.

m = modBuilder();
m.add('c', 'c^(-sig) - beta*R*c(1)^(-sig)');
m.add('b', 'b - R*b(-1) - yy + c');
m.parameter('sig', 2);
m.parameter('beta', 0.99);
m.parameter('R', 1/0.99);
m.exogenous('yy', 1);

lastwarn('');
b = m.steady_plan(Match=true);
[msg, id] = lastwarn();
assert(strcmp(id, 'modBuilder:steady_plan:endogenousUnitRoot'), 'the open-economy model must raise the endogenousUnitRoot warning');
assert(contains(msg, '"c"'), 'the warning must name the degenerate equation');

% Same model with the gross rate endogenous, pinned by the consistency equation.
m2 = modBuilder();
m2.add('c', 'c^(-sig) - beta*R*c(1)^(-sig)');
m2.add('R', 'R - 1/beta');
m2.add('b', 'b - R*b(-1) - yy + c');
m2.parameter('sig', 2);
m2.parameter('beta', 0.99);
m2.exogenous('yy', 1);

lastwarn('');
m2.steady_plan(Match=true);
[~, id] = lastwarn();
assert(strcmp(id, 'modBuilder:steady_plan:endogenousUnitRoot'), 'the endogenous-rate variant must raise the endogenousUnitRoot warning');

% Closing the model with a debt-elastic interest rate removes the unit root: the
% Euler now pins R, the premium equation pins b, and no warning must be issued.
m3 = modBuilder();
m3.add('c', 'c^(-sig) - beta*R*c(1)^(-sig)');
m3.add('R', 'R - Rbar + psi*(b - bbar)');
m3.add('b', 'b - R*b(-1) - yy + c');
m3.parameter('sig', 2);
m3.parameter('beta', 0.99);
m3.parameter('Rbar', 1/0.99);
m3.parameter('psi', 0.01);
m3.parameter('bbar', 0.5);
m3.exogenous('yy', 1);

lastwarn('');
b3 = m3.steady_plan(Match=true);
[~, id] = lastwarn();
assert(~strcmp(id, 'modBuilder:steady_plan:endogenousUnitRoot'), 'the debt-elastic closure must not raise the endogenousUnitRoot warning');
resolved = {};
for k = 1:numel(b3)
    for j = 1:numel(b3(k).closed_form)
        resolved{end+1} = b3(k).closed_form(j).var; %#ok<AGROW>
    end
end
assert(all(ismember({'R', 'b', 'c'}, resolved)), 'the closed model must resolve R, b and c in closed form');

fprintf('steady-plan/t36: endogenous unit roots are flagged at the pairing, closed models stay silent\n');

% --- A residual that is a multiple of the variable with a constant cofactor ---------
% junk = 0.9*junk(+1) reduces to 0.1*junk = 0, which fixes junk at zero: the cofactor
% cannot vanish, so the pairing admits junk for its own equation and no unit root is
% reported. The Euler equation above is different in kind: its cofactor 1 - beta*R is
% zero at this calibration, and c is genuinely free.
m4 = modBuilder();
m4.add('y', 'y = alpha*k(-1) + e');
m4.add('k', 'k = (1-delta)*k(-1) + i');
m4.add('i', 'i = s*y');
m4.add('junk', 'junk = 0.9*junk(+1)');
m4.parameter('alpha', 0.3);
m4.parameter('delta', 0.1);
m4.parameter('s', 0.2);
m4.exogenous('e', 0);

lastwarn('');
b4 = m4.steady_plan(Match=true);
[~, id] = lastwarn();
assert(~strcmp(id, 'modBuilder:steady_plan:endogenousUnitRoot'), 'a factored residual with a constant cofactor pins its variable and must not raise the unit-root warning');
found = false;
for k = 1:numel(b4)
    for j = 1:numel(b4(k).closed_form)
        if strcmp(b4(k).closed_form(j).var, 'junk')
            found = strcmp(b4(k).closed_form(j).expr, '0');
        end
    end
end
assert(found, 'junk should be closed at zero');

