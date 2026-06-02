% ast.to_latex — LaTeX rendering of equation expressions

% ---------------------------------------------------------------------------
% Bare rendering (no texname map): literal symbol names.
% ---------------------------------------------------------------------------
cases = {
    % expression          expected LaTeX
    'alpha',              'alpha'
    'K(-1)',              'K_{t-1}'
    'K(2)',               'K_{t+2}'
    'STEADY_STATE(K)',    'K^{\star}'
    'a + b',              'a + b'
    'a - b',              'a - b'
    'a*b',                'a\,b'
    '2*x',                '2\,x'
    'x*2',                'x \cdot 2'
    'a/b',                '\frac{a}{b}'
    'x^2',                'x^{2}'
    'x^(-1)',             'x^{-1}'
    '(a+b)^2',            '\left(a + b\right)^{2}'
    '(a/b)^c',            '\left(\frac{a}{b}\right)^{c}'
    'a*(b+c)',            'a\,\left(b + c\right)'
    'a - (b - c)',        'a - \left(b - c\right)'
    '-x',                 '-x'
    '-x*y',               '-x\,y'
    '-(a+b)',             '-\left(a + b\right)'
    'exp(x)',             'e^{x}'
    'exp(x+y)',           'e^{x + y}'
    'exp(x)^2',           '\left. e^{x} \right.^{2}'
    'log(x)',             '\log\left(x\right)'
    'sqrt(x)',            '\sqrt{x}'
    'cbrt(x)',            '\sqrt[3]{x}'
    'sin(x)',             '\sin\left(x\right)'
    'tanh(x)',            '\tanh\left(x\right)'
    'abs(x)',             '\left|x\right|'
    'max(a, b)',          '\max\left(a, b\right)'
    'normcdf(x)',         '\Phi\left(x\right)'
    'log(x)/y',           '\frac{\log\left(x\right)}{y}'
    'STEADY_STATE(K)^a',  '\left. K^{\star} \right.^{a}'
    };

for k = 1:size(cases, 1)
    expr = cases{k, 1};
    want = cases{k, 2};
    got = ast(expr).to_latex();
    assert(strcmp(got, want), sprintf('to_latex(%s): expected [%s], got [%s]', expr, want, got));
end

% ---------------------------------------------------------------------------
% With a texname map: greek letters substituted, names absent render literally.
% ---------------------------------------------------------------------------
m = struct('alpha', '\alpha', 'K', 'K', 'beta', '\beta');
assert(strcmp(ast('alpha').to_latex(m), '\alpha'), 'mapped alpha');
assert(strcmp(ast('gamma').to_latex(m), 'gamma'),  'unmapped name stays literal');
assert(strcmp(ast('alpha*K(-1)^alpha').to_latex(m), '\alpha\,K_{t-1}^{\alpha}'), 'mapped composite');
assert(strcmp(ast('STEADY_STATE(K)').to_latex(m), 'K^{\star}'), 'mapped steady state');

% ---------------------------------------------------------------------------
% On canonical (simplified) trees: the +/uminus and */^(-1) patterns are
% pretty-printed, and a lone negative power is kept as x^{-1}.
% ---------------------------------------------------------------------------
assert(strcmp(ast('a/b').simplify().to_latex(),       '\frac{a}{b}'),  'simplified division');
assert(strcmp(ast('a*b - c*d').simplify().to_latex(), '-c\,d + a\,b'), 'simplified difference of products');
assert(strcmp(ast('1/x').simplify().to_latex(),       'x^{-1}'),       'lone reciprocal kept as power');

% ---------------------------------------------------------------------------
% diff_ast → to_latex: derivatives render cleanly.
% ---------------------------------------------------------------------------
assert(strcmp(ast('log(C)').diff_ast('C').to_latex(), 'C^{-1}'), 'd(log C)/dC rendered');

% ---------------------------------------------------------------------------
% Dated variables: a bare sym in the `dated` set gets a current-period _t subscript;
% leads/lags keep their period; symbols absent from the set (parameters) stay bare.
% ---------------------------------------------------------------------------
assert(strcmp(ast('k').to_latex(struct(), {'k'}),       'k_t'),    'dated bare sym gets _t');
assert(strcmp(ast('alpha').to_latex(struct(), {'k'}),   'alpha'),  'undated sym (parameter) stays bare');
assert(strcmp(ast('h^2').to_latex(struct(), {'h'}),     'h_t^{2}'),'dated base keeps _t then exponent');
assert(strcmp(ast('y + alpha*k(-1)').to_latex(struct('alpha', '\alpha'), {'y', 'k'}), ...
              'y_t + \alpha\,k_{t-1}'), 'dated current y_t and lagged k_{t-1}, parameter bare');

% Underscores in an unmapped name are escaped so the literal is valid math (not an
% unintended or doubled subscript); a mapped texname is LaTeX and used verbatim.
assert(strcmp(ast('a_b_c').to_latex(),                      'a\_b\_c'),    'multi-underscore name escaped');
assert(strcmp(ast('c_h').to_latex(struct(), {'c_h'}),       'c\_h_t'),     'dated underscore name: escaped base + _t');
assert(strcmp(ast('c_h(-1)').to_latex(),                    'c\_h_{t-1}'), 'lagged underscore name escaped');
assert(strcmp(ast('a_b_c').to_latex(struct('a_b_c', '\xi')),'\xi'),        'mapped texname used verbatim, not escaped');

fprintf('t26.m: ast.to_latex OK\n');
