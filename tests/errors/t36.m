% Tests for subs()/substitute() implicit-loop placeholder and index errors

m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.parameter('alpha', 0.5);
m.exogenous('x', 0);
m.exogenous('e', 0);

% subs(): expr2 carries a placeholder absent from expr1
thrown = false;
try
    m.subs('a', 'b_$1', {1});
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:subs:placeholderMismatch');
end
assert(thrown, 'Expected subs:placeholderMismatch when expr2 has an extra placeholder.');

% subs(): placeholder present but no index value arrays supplied
thrown = false;
try
    m.subs('a_$1', 'b_$1');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:subs:indexMismatch');
end
assert(thrown, 'Expected subs:indexMismatch when no index arrays are supplied.');

% subs(): more than one char (equation-name) argument
thrown = false;
try
    m.subs('a', 'b', 'eq1', 'eq2');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:subs:multipleArgs');
end
assert(thrown, 'Expected subs:multipleArgs for two char arguments.');

% subs(): index arrays supplied but no placeholders anywhere
thrown = false;
try
    m.subs('alpha', 'beta', {1});
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:subs:placeholderMissing');
end
assert(thrown, 'Expected subs:placeholderMissing when index arrays accompany a plain substitution.');

% substitute(): expr1 and expr2 carry different placeholders (strict)
thrown = false;
try
    m.substitute('a_$1', 'b_$2', {1});
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:substitute:indexMismatch');
end
assert(thrown, 'Expected substitute:indexMismatch for mismatched placeholders.');
