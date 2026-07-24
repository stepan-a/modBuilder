% modBuilder.tex_linearise with Substitute=true: the declared steady state is inlined into the
% coefficients and reduced, so each elasticity comes out as a function of the deep parameters
% (x^{\star}/k^{\star} becomes \delta) instead of a ratio of steady-state levels.

m = modBuilder();
m.add('y', 'y = c + x');                    % resource constraint
m.add('c', 'c = beta*y');                   % consumption rule
m.add('x', 'x = delta*k(-1)');              % investment
m.add('k', 'k = (1-delta)*k(-1) + x');      % capital accumulation
m.parameter('beta',  0.6,   'texname', '\beta');
m.parameter('delta', 0.025, 'texname', '\delta');

% Steady state, normalised on y = 1: c = beta, x = 1 - beta, k = (1 - beta)/delta.
m.steady('y', '1');
m.steady('c', 'beta');
m.steady('x', '1-beta');
m.steady('k', '(1-beta)/delta');

tex = m.tex_linearise({'y','c','x','k'}, 'Substitute', true);

assert(startsWith(strtrim(tex), '\begin{align}') && endsWith(strtrim(tex), '\end{align}'), 'align block');

% Every coefficient is a deep parameter: no steady-state level survives.
assert(~contains(tex, '^{\star}'), 'no steady-state level left in the coefficients');

% c^{\star}/y^{\star} = beta and x^{\star}/y^{\star} = 1 - beta.
assert(contains(tex, '\hat{y}_t &= \beta\,\hat{c}_t + \left(1 - \beta\right)\,\hat{x}_t'), 'resource row in deep parameters');
% beta*y^{\star}/c^{\star} = 1 and delta*k^{\star}/x^{\star} = 1: a unit coefficient is dropped.
assert(contains(tex, '\hat{c}_t &= \hat{y}_t'), 'consumption row has a unit elasticity');
assert(contains(tex, '\hat{x}_t &= \hat{k}_{t-1}'), 'investment row has a unit elasticity');
% x^{\star}/k^{\star} = delta, next to the (1 - delta) of the accumulation itself.
assert(contains(tex, '\delta\,\hat{x}_t'), 'x^{\star}/k^{\star} collapses to delta');
assert(contains(tex, '\left(1 - \delta\right)\,\hat{k}_{t-1}'), 'depreciation coefficient kept');

% --- the default is unchanged: coefficients stay ratios of steady-state levels ----------------
plain = m.tex_linearise({'y','c','x','k'});
assert(contains(plain, '\frac{c^{\star}}{y^{\star}}'), 'default keeps the steady-state ratio');
assert(~strcmp(plain, tex), 'Substitute changes the rendering');

% --- Substitute needs a declared steady state -------------------------------------------------
mbad = modBuilder();
mbad.add('y', 'y = c + x');
mbad.add('c', 'c = beta*y');
mbad.add('x', 'x = delta*k(-1)');
mbad.add('k', 'k = (1-delta)*k(-1) + x');
mbad.parameter('beta', 0.6);
mbad.parameter('delta', 0.025);
caught = false;
try
    mbad.tex_linearise({'y','c','x','k'}, 'Substitute', true);
catch e
    caught = strcmp(e.identifier, 'modBuilder:tex_linearise:steadyStateRequired');
end
assert(caught, 'Substitute=true must require a declared steady state');

% --- Evaluate wins over Substitute: numeric coefficients, no error ----------------------------
m.endogenous('y', 1);
m.endogenous('c', 0.6);
m.endogenous('x', 0.4);
m.endogenous('k', 16);
texE = m.tex_linearise({'y','c','x','k'}, 'Evaluate', true, 'Substitute', true);
assert(contains(texE, '\hat{y}_t &= 0.6\,\hat{c}_t + 0.4\,\hat{x}_t'), 'Evaluate takes precedence');

% --- end-to-end compile -----------------------------------------------------------------------
if system('command -v pdflatex >/dev/null 2>&1') == 0
    for blk = {tex, texE}
        td = tempname; mkdir(td);
        cleanup = onCleanup(@() rmdir(td, 's')); %#ok<NASGU>
        doc = ['\documentclass{article}' newline '\usepackage{amsmath}' newline ...
               '\begin{document}' newline blk{1} newline '\end{document}' newline];
        texfile = fullfile(td, 'lin.tex');
        fid = fopen(texfile, 'w'); fprintf(fid, '%s', doc); fclose(fid);
        [st, out] = system(sprintf('pdflatex -interaction=nonstopmode -halt-on-error -output-directory ''%s'' ''%s''', td, texfile));
        assert(st == 0, sprintf('linearised LaTeX failed to compile:\n%s', out));
        clear cleanup;
    end
else
    fprintf('tex-linearise/t03.m: pdflatex not found, skipping the LaTeX compile check\n');
end

fprintf('tex-linearise/t03.m: tex_linearise Substitute OK\n');
