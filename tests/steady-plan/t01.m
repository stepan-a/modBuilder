% Tier 1 — empty model returns an empty plan struct array.

m = modBuilder();
plan = m.steady_plan();

if ~isempty(plan)
    error('Empty model should give an empty plan, got %d block(s).', numel(plan))
end
if ~isstruct(plan)
    error('Plan must be a struct array even when empty.')
end

fprintf('t01.m: empty model OK\n');
