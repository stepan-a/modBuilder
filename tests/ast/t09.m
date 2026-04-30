% Parser error handling

cases = {
    ''                       % empty
    'a +'                    % missing operand
    '(a + b'                 % unclosed paren
    'a + b)'                 % stray close paren
    'a @ b'                  % bad character
    'x(1.5)'                 % non-integer time subscript
    'STEADY_STATE(a + b)'    % STEADY_STATE expects a bare symbol
    };

for i = 1:numel(cases)
    s = cases{i};
    threw = false;
    try
        ast(s);
    catch
        threw = true;
    end
    assert(threw, sprintf('expected parse error for "%s"', s));
end
