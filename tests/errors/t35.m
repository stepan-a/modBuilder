% Tests for flip() and rmflip() error paths

m = modBuilder();
m.add('y', 'y = alpha*k + e');
m.add('k', 'k = beta*y + u');
m.add('z', 'z = rho*z(-1) + w');
m.parameter('alpha', 0.3);
m.parameter('beta', 0.5);
m.parameter('rho', 0.9);
m.exogenous('e', 0);
m.exogenous('u', 0);
m.exogenous('w', 0);

% flip(): the two names carry different placeholders
thrown = false;
try
    m.flip('y_$1', 'x_$2', {1});
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:flip:indexMismatch');
end
assert(thrown, 'Expected flip:indexMismatch for mismatched placeholders.');

% flip(): more index arrays than placeholders
thrown = false;
try
    m.flip('y_$1', 'x_$1', {1}, {2});
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:flip:indexMismatch');
end
assert(thrown, 'Expected flip:indexMismatch for too many index arrays.');

% rmflip(): the two names carry different placeholders
thrown = false;
try
    m.rmflip('y_$1', 'k_$2', {1});
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:rmflip:indexMismatch');
end
assert(thrown, 'Expected rmflip:indexMismatch for mismatched placeholders.');

% rmflip(): eqname is not a known equation
thrown = false;
try
    m.rmflip('ghost', 'k');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:rmflip:unknownSymbol');
end
assert(thrown, 'Expected rmflip:unknownSymbol for an unknown equation.');

% rmflip(): newexo is not an endogenous variable
thrown = false;
try
    m.rmflip('y', 'e');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:rmflip:notEndogenous');
end
assert(thrown, 'Expected rmflip:notEndogenous when newexo is exogenous.');

% rmflip(): eqname's variable does not appear in newexo's equation
% (z does not appear in y's equation, so reassigning would not determine z)
thrown = false;
try
    m.rmflip('z', 'y');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:rmflip:notInEquation');
end
assert(thrown, 'Expected rmflip:notInEquation when eqname is absent from newexo''s equation.');
