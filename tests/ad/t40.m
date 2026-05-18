% Test overloaded tan function: asymptote detection must work at large x.
% The pre-patch check was |((x - pi/2)/pi) - round(...)| > 1e-15 — a modular
% reduction that loses precision as x grows. Post-patch the test thresholds
% the actual denominator cos(o.x) with an eps(o.x)-scaled tolerance, so it
% remains reliable far from the origin.

% Smooth point near origin: tan(pi/4) = 1, derivative = 1/cos(pi/4)^2 = 2.
a = tan(autoDiff1(pi/4, 1));
assert(abs(a.x  - 1) < 1e-12, 'tan(pi/4).x should be 1');
assert(abs(a.dx - 2) < 1e-12, 'tan(pi/4).dx should be 2');

% Smooth point far from origin: tan(5*pi) ≈ 0, derivative ≈ 1.
b = tan(autoDiff1(5*pi, 1));
assert(abs(b.x)            < 1e-10, 'tan(5*pi).x should be ~0');
assert(abs(b.dx - 1)       < 1e-10, 'tan(5*pi).dx should be ~1');

% Asymptote at pi/2: must error.
threw = false;
try
    tan(autoDiff1(pi/2, 1));
catch e
    threw = true;
    assert(strcmp(e.identifier, 'autoDiff1:tan:asymptote'), ...
           'Expected autoDiff1:tan:asymptote, got %s', e.identifier);
end
assert(threw, 'tan(pi/2) should error');

% Asymptote far from origin (11*pi/2): must error — this is the case the
% pre-patch modular test could silently miss because (o.x - pi/2)/pi loses
% precision and might appear "off-integer" by more than 1e-15.
threw = false;
try
    tan(autoDiff1(11*pi/2, 1));
catch e
    threw = true;
    assert(strcmp(e.identifier, 'autoDiff1:tan:asymptote'), ...
           'Expected autoDiff1:tan:asymptote, got %s', e.identifier);
end
assert(threw, 'tan(11*pi/2) should error');
