% modBuilder.tex_linearise with augment multipliers as LevelVars: the Lagrange multipliers a
% Ramsey augmentation introduces have a zero/negative steady state and cannot be log-linearised,
% so they are marked LevelVars and enter as level deviations (mult_t - mult^{\star}), while the
% other variables stay log-linear in the same (consistent) system.

m = modBuilder();
m.add('pi', 'pi = beta*pi(+1) + kappa*y');                 % NKPC
m.add('y',  'y = y(+1) - sigma*(i - pi(+1))');             % IS
m.add('W',  'W = -(pi^2 + lambda*y^2)/2 + beta*W(+1)');    % recursive welfare
m.parameter('beta',   0.99, 'texname', '\beta');
m.parameter('kappa',  0.1,  'texname', '\kappa');
m.parameter('sigma',  1,    'texname', '\sigma');
m.parameter('lambda', 0.5,  'texname', '\lambda');
m.exogenous('i', 0);
m.endogenous('pi', [], 'texname', '\pi');                  % nicer log-deviation \hat{\pi}

r = m.ramsey_foc('W', {'i'});
m.augment(r);   % adds mult_1, mult_2 (texname \mu_{1}, \mu_{2}) and the FOC equations

% augment keys FOC(i) to the instrument i, which appears in no FOC, so that equation cannot be
% normalised on i; linearise the equations that normalise cleanly (the two constraints and the two
% multiplier FOCs), with the multipliers entering as level deviations.
tex = m.tex_linearise({'pi','y','mult_1','mult_2'}, 'LevelVars', {'mult_1','mult_2'});

assert(startsWith(strtrim(tex), '\begin{align}') && endsWith(strtrim(tex), '\end{align}'), 'align block');
assert(contains(tex, ' &= '), 'rows aligned on the equals sign');

% The multipliers enter as level deviations (current and lagged), with the braced \mu_{i} subscript.
assert(contains(tex, '\left({\mu_{1}}_t - \mu_{1}^{\star}\right)'),     'mult_1 current level deviation');
assert(contains(tex, '\left({\mu_{2}}_t - \mu_{2}^{\star}\right)'),     'mult_2 current level deviation');
assert(contains(tex, '\left({\mu_{1}}_{t-1} - \mu_{1}^{\star}\right)'), 'mult_1 lagged level deviation');

% A LevelVar is never hatted; the log variables (pi, y) are.
assert(~contains(tex, '\hat{\mu'), 'multipliers are not log-linearised');
assert(~contains(tex, '\hat{mult'), 'multipliers are not log-linearised (literal)');
assert(contains(tex, '\hat{\pi}'), 'pi enters as a log deviation');
assert(contains(tex, '\hat{y}'),   'y enters as a log deviation');

% End-to-end: the mixed log/level system must compile (the braced \mu_{i} subscripts and the
% \mu_{i}^{\star} superscripts are the delicate part).
if system('command -v pdflatex >/dev/null 2>&1') == 0
    td = tempname; mkdir(td);
    cleanup = onCleanup(@() rmdir(td, 's')); %#ok<NASGU>
    doc = ['\documentclass{article}' newline '\usepackage{amsmath}' newline ...
           '\begin{document}' newline tex newline '\end{document}' newline];
    texfile = fullfile(td, 'lin.tex');
    fid = fopen(texfile, 'w'); fprintf(fid, '%s', doc); fclose(fid);
    [st, out] = system(sprintf('pdflatex -interaction=nonstopmode -halt-on-error -output-directory ''%s'' ''%s''', td, texfile));
    assert(st == 0, sprintf('linearised Ramsey LaTeX failed to compile:\n%s', out));
    assert(isfile(fullfile(td, 'lin.pdf')), 'pdflatex reported success but produced no PDF');
else
    fprintf('tex-linearise/t02.m: pdflatex not found, skipping the LaTeX compile check\n');
end

fprintf('tex-linearise/t02.m: tex_linearise with augment multipliers OK\n');
