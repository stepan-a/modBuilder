% modBuilder.tex_steady_state_plan — recursively-ordered steady-state TeX: an analytic prologue
% (closed-form solutions), a numerical core (residual systems), and an analytic epilogue whose
% solutions are written in terms of the core unknowns. Blocks come from steady_plan, not from
% declaration order.

% Declared OUT of recursive order (w first, z last) to check the method reorders:
%   z = alpha            -> recursive, analytic (prologue)
%   x = y^2 + z          \  jointly nonlinear in x, y -> numerical core
%   y = x^2 + 1          /
%   w = x + y            -> recursive, analytic given the core unknowns (epilogue)
m = modBuilder();
m.add('w', 'w = x + y');
m.add('y', 'y = x^2 + 1');
m.add('x', 'x = y^2 + z');
m.add('z', 'z = alpha');
m.parameter('alpha', 0.5, 'texname', '\alpha');

tex = m.tex_steady_state_plan();

assert(startsWith(strtrim(tex), '\begin{align}') && endsWith(strtrim(tex), '\end{align}'), 'align block');

% Prologue: z solved in closed form from the parameter.
assert(contains(tex, 'z^{\star} &= \alpha'), 'prologue solved form');

% Core: the simultaneous (x, y) block is left as a residual system (= 0), with starred bases under
% powers using invisible delimiters.
assert(contains(tex, '\left. y^{\star} \right.^{2}'), 'core residual: y^2 with invisible delimiters');
assert(contains(tex, '\left. x^{\star} \right.^{2}'), 'core residual: x^2 with invisible delimiters');
assert(numel(strfind(tex, '&= 0')) == 2, 'exactly the two core equations are residuals');

% Epilogue: w solved analytically AS A FUNCTION OF the core unknowns x, y.
assert(contains(tex, 'w^{\star} &= x^{\star} + y^{\star}'), 'epilogue solved form in terms of the core unknowns');

% Recursive order, not declaration order: z (declared last) comes first, w (declared first) last.
zpos = strfind(tex, 'z^{\star} &=');
wpos = strfind(tex, 'w^{\star} &=');
assert(~isempty(zpos) && ~isempty(wpos) && zpos(1) < wpos(1), 'prologue precedes epilogue (reordered)');

% Blocks are separated by a little vertical space, with no headers.
assert(contains(tex, '\\[\medskipamount]'), 'blocks separated by vertical space');
assert(~contains(tex, '\text{'), 'no block headers');

% Writing to a file produces exactly the returned string.
fname = [tempname '.tex'];
m.tex_steady_state_plan(fname);
written = fileread(fname);
delete(fname);
assert(strcmp(written, tex), 'file content matches the returned string');

% End-to-end: the mixed solved-form / residual block must compile.
if system('command -v pdflatex >/dev/null 2>&1') == 0
    td = tempname; mkdir(td);
    cleanup = onCleanup(@() rmdir(td, 's')); %#ok<NASGU>
    doc = ['\documentclass{article}' newline '\usepackage{amsmath}' newline ...
           '\begin{document}' newline tex newline '\end{document}' newline];
    texfile = fullfile(td, 'plan.tex');
    fid = fopen(texfile, 'w'); fprintf(fid, '%s', doc); fclose(fid);
    [st, out] = system(sprintf('pdflatex -interaction=nonstopmode -halt-on-error -output-directory ''%s'' ''%s''', td, texfile));
    assert(st == 0, sprintf('steady-state plan LaTeX failed to compile:\n%s', out));
    assert(isfile(fullfile(td, 'plan.pdf')), 'pdflatex reported success but produced no PDF');
else
    fprintf('tex-plan/t01.m: pdflatex not found, skipping the LaTeX compile check\n');
end

fprintf('tex-plan/t01.m: tex_steady_state_plan OK\n');
