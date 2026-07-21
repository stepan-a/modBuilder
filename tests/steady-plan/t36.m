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
