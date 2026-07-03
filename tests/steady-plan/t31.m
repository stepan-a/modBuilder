% suggest_anchors: reduce a pool of candidate anchors to the ones the plan needs.
%
% The candidate pool holds the values the modeller declared as known: p, the
% symmetric relative price (a value the plan can also derive from the freed
% optimal-price equation once y is known), and y, whose equation is a genuine
% quadratic that no recogniser closes (as in steady-plan/t28). suggest_anchors
% must drop p (deducible) and keep y (its anchor is what closes the model).

m = modBuilder();
m.add('p', 'z1/z2 = p');
m.add('z1', 'lam*y = z1 - del*z1');
m.add('z2', 'lam*y = z2 - dee*z2');
m.add('y', 'y^2 + s*y = c');
m.parameter('lam', 2);
m.parameter('del', 0.5);
m.parameter('dee', 0.6);
m.parameter('s', 1);
m.parameter('c', 6);
m.steady('p', '(1-dee)/(1-del)');
m.steady('y', '2');            % the positive root of y^2 + s*y - c = 0

% Default candidates: the endogenous variables with a declared steady value.
out = m.suggest_anchors();
assert(isequal(out.anchors, {'y'}), 'y must be kept: its quadratic is not closable');
assert(isequal(out.dropped, {'p'}), 'p must be dropped: the freed equation derives it');
assert(out.residual == 0 && isempty(out.open), 'the reduced set must close the model');

% The plan under the reduced set derives p with the correct value. (p's declared
% value may stay in the steady table: it is compound, so PropagateKnown ignores it.)
b = m.steady_plan(Match=true, Anchors=out.anchors, PropagateKnown=true);
vals = struct('lam',2,'del',0.5,'dee',0.6,'s',1,'c',6,'y',2);
for k = 1:numel(b)
    for jj = 1:numel(b(k).closed_form)
        cf = b(k).closed_form(jj);
        vals.(cf.var) = ast(cf.expr).eval(vals);
    end
end
assert(abs(vals.p - (1-0.6)/(1-0.5)) < 1e-12, 'derived p must equal (1-dee)/(1-del)');

% Keep option: a kept anchor is never tested.
out2 = m.suggest_anchors(Candidates={'p'}, Keep={'y'});
assert(isequal(out2.anchors, {'y'}) && isequal(out2.dropped, {'p'}) && out2.residual == 0);

fprintf('steady-plan/t31: suggest_anchors keeps {%s}, drops {%s}\n', strjoin(out.anchors, ', '), strjoin(out.dropped, ', '));
