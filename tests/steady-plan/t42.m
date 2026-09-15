% suggest_calibrations widens its scan to the whole stalled block when the variables
% left open yield nothing; suggest_anchors removes the declared values it drops.
%
% The small RBC model with a fixed cost of production stalls on a five-variable block
% and leaves investment open, whose equation, the resource constraint, has no
% parameter: the first scan has nothing to try. Pinning hours and freeing theta closes
% the plan.

build = @() local_fixedcost();

m = build();
b = m.steady_plan(Match=true, PropagateKnown=true);
assert(~isempty(local_open(b)), 'the fixed-cost model should stall');
s = m.suggest_calibrations(b, Match=true, PropagateKnown=true);
assert(~isempty(s), 'the widened scan should find swaps');
full = s([s.residual] == 0);
assert(any(strcmp({full.endo}, 'h') & strcmp({full.param}, 'theta')), 'pinning h and freeing theta should be a full closure');
assert(all(diff([s.residual]) >= 0), 'suggestions should be sorted by ascending residual');
m.calibrate('h', 1/3, 'theta');
assert(isempty(local_open(m.steady_plan(Match=true, PropagateKnown=true))), 'the swap should close the plan');

% suggest_anchors keeps output, drops hours and capital, and removes their declarations.
m2 = build();
m2.steady('h', '0.5586029261');
m2.steady('k', '21.2209081886');
m2.steady('y', '1.9690980908');
out = m2.suggest_anchors();
assert(isequal(out.anchors, {'y'}) && isequal(sort(out.dropped), {'h', 'k'}) && out.residual == 0, 'y alone should be kept');
assert(isequal(m2.steady_state(:, 1)', {'y'}), 'the dropped declarations should be removed');
assert(isempty(local_open(m2.steady_plan(Match=true, Anchors=out.anchors, PropagateKnown=true))), 'y as the only anchor should close the plan');

% Apply=false only reports.
m3 = build();
m3.steady('h', '0.5586029261');
m3.steady('k', '21.2209081886');
m3.steady('y', '1.9690980908');
out3 = m3.suggest_anchors(Apply=false);
assert(isequal(out3.anchors, {'y'}) && size(m3.steady_state, 1) == 3, 'Apply=false should leave every declaration in place');

function m = local_fixedcost()
    m = modBuilder();
    m.add('a', 'a = rho*a(-1) + e');
    m.add('y', 'y = exp(a)*k(-1)^alpha*h^(1-alpha) - phi');
    m.add('k', 'k = (1-delta)*k(-1) + i');
    m.add('i', 'y = c + i');
    m.add('c', '1/beta = c/c(+1)*(alpha*(y(+1)+phi)/k + 1 - delta)');
    m.add('h', 'theta*c*h^psi = (1-alpha)*(y+phi)/h');
    m.parameter('alpha', 0.36);
    m.parameter('beta', 0.99);
    m.parameter('delta', 0.025);
    m.parameter('rho', 0.95);
    m.parameter('theta', 2.95);
    m.parameter('psi', 1);
    m.parameter('phi', 0.1);
    m.exogenous('e', 0);
end

function o = local_open(bl)
% The variables a plan leaves open: those of a non-anchor block without a closed form.
    o = {};
    for k = 1:numel(bl)
        if strcmp(bl(k).kind, 'anchor'), continue, end
        o = [o, setdiff(bl(k).vars, {bl(k).closed_form.var})]; %#ok<AGROW>
    end
end
