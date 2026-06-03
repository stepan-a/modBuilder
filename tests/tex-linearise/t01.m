% modBuilder.tex_linearise — render the log-linearised model, normalized on each equation's
% keyed variable, with symbolic (^{\star}) or numeric coefficients.

m = modBuilder();
m.add('y', 'y = c + x');                    % resource constraint
m.add('c', 'c = beta*y');                   % consumption rule
m.add('x', 'x = delta*k(-1)');              % investment
m.add('k', 'k = (1-delta)*k(-1) + x');      % capital accumulation
m.parameter('beta',  0.6,   'texname', '\beta');
m.parameter('delta', 0.025, 'texname', '\delta');

% --- symbolic coefficients (default) ---------------------------------------------------------
tex = m.tex_linearise();
assert(startsWith(strtrim(tex), '\begin{align}'), 'starts with \begin{align}');
assert(endsWith(strtrim(tex),   '\end{align}'),   'ends with \end{align}');
assert(contains(tex, ' &= '), 'rows aligned on the equals sign');

% Shares as SS-symbolic coefficients; lags carry their period.
assert(contains(tex, '\hat{y}_t &= \frac{c^{\star}}{y^{\star}}\,\hat{c}_t + \frac{x^{\star}}{y^{\star}}\,\hat{x}_t'), 'resource row');
assert(contains(tex, '\hat{c}_t &= \frac{\beta\,y^{\star}}{c^{\star}}\,\hat{y}_t'), 'consumption row');
% Capital accumulation: the depreciation coefficient prints as the readable (1 - delta), not -(-1 + delta).
assert(contains(tex, '\hat{k}_t &= \frac{x^{\star}}{k^{\star}}\,\hat{x}_t + \left(1 - \delta\right)\,\hat{k}_{t-1}'), 'capital row with clean (1 - delta)');

% --- LevelVars: a level deviation, and no double superscript on a starred base ----------------
texL = m.tex_linearise({'y','c','x','k'}, 'LevelVars', {'x'});
assert(contains(texL, '\left(x_t - x^{\star}\right)'), 'x enters as a level deviation');
% 1/y^{\star} as a coefficient must use invisible delimiters, not the invalid y^{\star}^{-1}.
assert(contains(texL, '\left. y^{\star} \right.^{-1}'), 'starred base under a power uses invisible delimiters');
assert(~contains(texL, 'star}^{-1}'), 'no double superscript');

% --- Evaluate=true: numeric coefficients at the (set) steady state ----------------------------
m.endogenous('y', 1);
m.endogenous('c', 0.6);
m.endogenous('x', 0.4);
m.endogenous('k', 16);
texE = m.tex_linearise({'y','c','x','k'}, 'Evaluate', true);
assert(contains(texE, '\hat{y}_t &= 0.6\,\hat{c}_t + 0.4\,\hat{x}_t'), 'numeric resource row');
assert(contains(texE, '0.975\,\hat{k}_{t-1}'), 'numeric depreciation coefficient 1 - delta = 0.975');

% Evaluate=true without a solved/set steady state errors clearly.
mbad = modBuilder();
mbad.add('y', 'y = c + x');
mbad.add('c', 'c = beta*y');
mbad.add('x', 'x = delta*k(-1)');
mbad.add('k', 'k = (1-delta)*k(-1) + x');
mbad.parameter('beta', 0.6);
mbad.parameter('delta', 0.025);
caught = false;
try
    mbad.tex_linearise({'y','c','x','k'}, 'Evaluate', true);
catch e
    caught = strcmp(e.identifier, 'modBuilder:steady_values_struct:missingValue');
end
assert(caught, 'Evaluate=true must require a steady state');

% --- end-to-end compile (catches double sub/superscripts) -------------------------------------
if system('command -v pdflatex >/dev/null 2>&1') == 0
    for blk = {tex, texL, texE}
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
    fprintf('tex-linearise/t01.m: pdflatex not found, skipping the LaTeX compile check\n');
end

fprintf('tex-linearise/t01.m: tex_linearise OK\n');
