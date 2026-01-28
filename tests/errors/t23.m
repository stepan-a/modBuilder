% Tests for autoDiff1 max and min branches

a = autoDiff1(5, 1);
b = autoDiff1(3, 0);

% Test 1: max — first argument greater
q = max(a, b);
assert(q.x == 5 && q.dx == 1, 'max should return first (larger).');

% Test 2: max — second argument greater
q = max(b, a);
assert(q.x == 5 && q.dx == 1, 'max should return second (larger).');

% Test 3: max — equal arguments (error)
thrown = false;
try
    max(autoDiff1(3, 1), autoDiff1(3, 0));
catch
    thrown = true;
end
assert(thrown, 'Expected error: max non-differentiable when equal.');

% Test 4: min — first greater (returns second)
q = min(a, b);
assert(q.x == 3 && q.dx == 0, 'min should return second (smaller).');

% Test 5: min — second greater (returns first)
q = min(b, a);
assert(q.x == 3 && q.dx == 0, 'min should return first (smaller).');

% Test 6: min — equal arguments (error)
thrown = false;
try
    min(autoDiff1(3, 1), autoDiff1(3, 0));
catch
    thrown = true;
end
assert(thrown, 'Expected error: min non-differentiable when equal.');
