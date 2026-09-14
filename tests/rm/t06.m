% rm and remove accept a bytag selector.

% The two-sector model of the introduction deck.
build = @() local_sectors();

% A selector removes what listeqbytag would name, with the same consequences.
a = build(); a.rm(bytag('sector', 'm'));
b = build(); eqs = b.listeqbytag('sector', 'm'); b.rm(eqs{:});
assert(isequal(sort(a.equations(:,1)'), {'C', 'K_s', 'Y_s'}), sprintf('Unexpected equations: %s', strjoin(a.equations(:,1)', ' ')));
assert(isequal(sort(a.varexo(:,1)'), sort(b.varexo(:,1)')) && isequal(sort(a.params(:,1)'), sort(b.params(:,1)')), 'A selector should remove exactly what the composition removes.');
assert(a.isexogenous('Y_m') && ~a.isendogenous('K_m') && ~a.isexogenous('K_m') && ~a.isparameter('A_m'), 'Y_m, still used by C, should become exogenous; K_m and A_m should go.');

% remove takes a selector too.
c = build(); c.remove(bytag('type', 'production'));
assert(isequal(sort(c.equations(:,1)'), {'C', 'K_m', 'K_s'}), sprintf('Unexpected equations: %s', strjoin(c.equations(:,1)', ' ')));

% Names and selectors together; an equation named twice is removed once.
d = build(); d.rm('C', bytag('type', 'acc.*'), 'K_m');
assert(isequal(sort(d.equations(:,1)'), {'Y_m', 'Y_s'}), sprintf('Unexpected equations: %s', strjoin(d.equations(:,1)', ' ')));

% A selector that matches nothing, or an unknown name, leaves the model untouched.
e = build();
thrown = '';
try
    e.rm('C', bytag('sector', 'agriculture'));
catch ME
    thrown = ME.identifier;
end
assert(strcmp(thrown, 'modBuilder:listeqbytag:noMatch') && e.size('equations') == 5, 'A selector matching nothing should fail before anything is removed.');
thrown = '';
try
    e.rm(bytag('sector', 'm'), 'ghost');
catch ME
    thrown = ME.identifier;
end
assert(strcmp(thrown, 'modBuilder:remove:unknownSymbol') && e.size('equations') == 5, 'An unknown name should fail before anything is removed.');

% A selector with no criteria would select every equation: refused, by rm and remove.
for call = {@(m) m.rm(bytag()), @(m) m.remove(bytag())}
    f = build();
    thrown = '';
    try
        call{1}(f);
    catch ME
        thrown = ME.identifier;
    end
    assert(strcmp(thrown, 'modBuilder:rm:emptySelector') && f.size('equations') == 5, sprintf('An empty selector should be refused, got "%s".', thrown));
end

% Selectors do not combine with index values, and remove still wants a name or a selector.
f = build();
cases = {@() f.remove(bytag('sector', 'm'), {'m', 's'}), 'modBuilder:remove:badSelector'; ...
         @() f.rm('Y_$1', bytag('sector', 'm')), 'modBuilder:rm:badType'; ...
         @() f.remove(42), 'modBuilder:remove:badType'};
for k = 1:size(cases, 1)
    thrown = '';
    try
        cases{k, 1}();
    catch ME
        thrown = ME.identifier;
    end
    assert(strcmp(thrown, cases{k, 2}), sprintf('Expected %s, got "%s".', cases{k, 2}, thrown));
end
assert(f.size('equations') == 5, 'A refused call should leave the model untouched.');

function m = local_sectors()
    m = modBuilder();
    m.add('Y_$1', 'Y_$1 = A_$1*K_$1(-1)^alpha*L_$1^(1-alpha)', {'m', 's'});
    m.add('K_$1', 'K_$1 = (1-delta)*K_$1(-1) + I_$1', {'m', 's'});
    m.add('C', 'C = Y_m + Y_s - I_m - I_s');
    m.parameter('A_$1', 1, {'m', 's'});
    m.parameter('alpha', 0.33);
    m.parameter('delta', 0.025);
    m.exogenous('L_$1', 1, {'m', 's'});
    m.exogenous('I_$1', 0.1, {'m', 's'});
    m.tag('Y_$1', 'type', 'production', {'m', 's'});
    m.tag('K_$1', 'type', 'accumulation', {'m', 's'});
    m.tag('Y_$1', 'sector', '$1', {'m', 's'});
    m.tag('K_$1', 'sector', '$1', {'m', 's'});
    m.tag('C', 'type', 'aggregation');
end
