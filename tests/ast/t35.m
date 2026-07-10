% canonicalise idempotency and canon-flag soundness.
%
% canonicalise memoises its fixed point in the node's canon flag and
% short-circuits on it. That is sound ONLY if canonicalise reaches the fixed
% point in a single pass (idempotent) and if every mutation clears the flag.
% A stale canon=true would return a non-canonical form -- a silent wrong
% answer -- so this test guards both properties directly.

addpath ../utils

exprs = { ...
  'a-b', 'a/b', 'a-(-b)', '(a-b)*(c-d)', 'x + y - x', 'a*b - b*a', ...
  '(1-b)/(-1+b)', '((x^(1-g))^(1-t))^-1', 'a/(c+d*x) + b/(c+d*x) - e', ...
  'exp(a/b)*c - d/e', 'log((a+b*x)/(c+d*x))', '-(-(-(a+b)))', ...
  '(a+b)^3 - c', 'x*y*z*w*v*u - u*v*w*x*y*z', 'a^2*b - b*a*a', ...
  '(a-b)/(b-a)', '-(a-b)*(b-a)', 'a + b + c + d - a - c'};

for i = 1:numel(exprs)
    c1 = ast(exprs{i}).canonicalise();
    % Force a genuine second pass by clearing the memoised flag, then check the
    % result is byte-identical: the first pass must already be a fixed point.
    c1b = c1;
    c1b.canon = false;
    c2 = c1b.canonicalise();
    assert(strcmp(c1.string(), c2.string()), ...
        'canonicalise not idempotent on "%s": "%s" vs "%s"', exprs{i}, c1.string(), c2.string());
    % The flag must be set after canonicalise.
    assert(c1.canon, 'canon flag must be set after canonicalise on "%s"', exprs{i});
end

% A substitution that actually rewrites a compound node must clear the flag
% (a no-op substitute on an absent symbol legitimately keeps it, so use a
% symbol that is present and yields a compound result).
m = ast('a/(c+d*x) + b/(c+d*x) - e').canonicalise().substitute('x', ast('y+1'), {});
assert(~m.canon, 'a rewriting substitute must clear the canon flag');

% Substituting into a canonical tree and re-canonicalising must equal building
% and canonicalising from scratch -- i.e. the flag never strands a stale form.
base = ast('a/(c+d*x) + b/(c+d*x) - e').canonicalise();
viaflag = base.substitute('x', ast('y+1'), {}).canonicalise().string();
scratch = ast('a/(c+d*(y+1)) + b/(c+d*(y+1)) - e').canonicalise().string();
assert(strcmp(viaflag, scratch), 'flag stranded a stale form: "%s" vs "%s"', viaflag, scratch);

% simplify must be unaffected by the flag: a numeric spot check on a rational
% residual whose value is known.
r = ast('(2+3*x)/(1+x) - 4').isolate('x');
assert(abs(r.eval(struct()) + 2) < 1e-12, 'simplify/isolate value changed under the canon flag');

fprintf('ast/t35: canonicalise idempotency and canon-flag soundness\n');
