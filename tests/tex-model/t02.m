% modBuilder.augment + tex_model — the augmented optimal-policy model renders to compilable
% LaTeX. The Lagrange multipliers are endogenous (hence dated), and their \mu_{i} texnames
% already carry a subscript, so to_latex must brace-wrap the base before the time index
% ({\mu_{1}}_t, {\mu_{1}}_{t-1}) to avoid an invalid double subscript.

m = modBuilder();
m.add('pi', 'pi = beta*pi(+1) + kappa*y');                 % NKPC
m.add('y',  'y = y(+1) - sigma*(i - pi(+1))');             % IS
m.add('W',  'W = -(pi^2 + lambda*y^2)/2 + beta*W(+1)');    % recursive welfare
m.parameter('beta',   0.99, 'texname', '\beta');
m.parameter('kappa',  0.1,  'texname', '\kappa');
m.parameter('sigma',  1,    'texname', '\sigma');
m.parameter('lambda', 0.5,  'texname', '\lambda');
m.exogenous('i', 0);

% (pi/y/W/i are left without a texname: they render literally, dated.)
r = m.ramsey_foc('W', {'i'});
m.augment(r);

tex = m.tex_model();

% The multipliers are dated and their \mu_{i} texname carries a subscript, so the base is
% brace-wrapped before the time index — both the current period and the lag.
assert(contains(tex, '{\mu_{1}}_t'),     'mult_1 current period brace-wrapped');
assert(contains(tex, '{\mu_{1}}_{t-1}'), 'mult_1 lag brace-wrapped');
assert(contains(tex, '{\mu_{2}}_t'),     'mult_2 current period brace-wrapped');
assert(contains(tex, '{\mu_{2}}_{t-1}'), 'mult_2 lag brace-wrapped');

% End-to-end: the produced LaTeX must actually compile (the double-subscript would be a hard
% LaTeX error). Skipped (not failed) where no LaTeX toolchain is available.
if system('command -v pdflatex >/dev/null 2>&1') == 0
    td = tempname;
    mkdir(td);
    cleanup = onCleanup(@() rmdir(td, 's'));   %#ok<NASGU>
    doc = ['\documentclass{article}' newline ...
           '\usepackage{amsmath}'   newline ...
           '\begin{document}'       newline ...
           tex                      newline ...
           '\end{document}'         newline];
    texfile = fullfile(td, 'ramsey.tex');
    fid = fopen(texfile, 'w');
    fprintf(fid, '%s', doc);
    fclose(fid);
    [st, out] = system(sprintf('pdflatex -interaction=nonstopmode -halt-on-error -output-directory ''%s'' ''%s''', td, texfile));
    assert(st == 0, sprintf('augmented-model LaTeX failed to compile:\n%s', out));
    assert(isfile(fullfile(td, 'ramsey.pdf')), 'pdflatex reported success but produced no PDF');
else
    fprintf('tex-model/t02.m: pdflatex not found, skipping the LaTeX compile check\n');
end

fprintf('tex-model/t02.m: augment + tex_model OK\n');
