% Tests for set_optional_fields:unknownProperty via declarations

% The symbols must already appear in the model, otherwise declare_symbol
% raises unknownSymbol before reaching the attribute parser.
m = modBuilder();
m.add('y', 'y = alpha*x');

% Unknown attribute key on a parameter declaration
thrown = false;
try
    m.parameter('alpha', 0.5, 'bogus', 'x');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:set_optional_fields:unknownProperty');
end
assert(thrown, 'Expected set_optional_fields:unknownProperty for a parameter.');

% Unknown attribute key on an exogenous declaration (exercises the
% '<type> variable' label branch)
thrown = false;
try
    m.exogenous('x', 0, 'bogus', 'x');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:set_optional_fields:unknownProperty');
end
assert(thrown, 'Expected set_optional_fields:unknownProperty for an exogenous variable.');
