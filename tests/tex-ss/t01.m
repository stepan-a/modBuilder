% modBuilder.tex_steady_state_system — render the steady-state system as left-aligned
% residual equations, with the steady-state superscript on the endogenous variables.

m = modBuilder();
m.add('k', 'k = (1-delta)*k(-1) + x');     % capital accumulation
m.add('x', 'x = delta*k(-1)');             % investment
m.add('a', 'a = rho*a(-1) + e');           % AR(1) forcing
m.parameter('delta', 0.025, 'texname', '\delta');
m.parameter('rho',   0.95,  'texname', '\rho');
m.exogenous('e', 0, 'texname', '\varepsilon');

tex = m.tex_steady_state_system();

% Wrapped in a single align environment.
assert(startsWith(strtrim(tex), '\begin{align}'), 'starts with \begin{align}');
assert(endsWith(strtrim(tex),   '\end{align}'),   'ends with \end{align}');

% Left-aligned residual form: every equation row starts at the align column (a leading '&',
% after the indent) and ends in " = 0"; the equals sign is NOT the alignment point.
assert(~contains(tex, '&='), 'equations are left-aligned, not aligned on the equals sign');
lines = strsplit(tex, newline);
nrows = 0;
for i = 1:numel(lines)
    L = lines{i};
    if isempty(strtrim(L)) || contains(L, 'begin{align}') || contains(L, 'end{align}')
        continue
    end
    nrows = nrows + 1;
    assert(startsWith(L, '  &'), sprintf('row should start at the left align column: %s', L));
    rhs = strtrim(erase(L, '\\'));   % drop a trailing row break before checking the suffix
    assert(endsWith(rhs, '= 0'),    sprintf('row should be a residual set to zero: %s', L));
end
assert(nrows == 3, sprintf('expected 3 equation rows, got %u', nrows));

% Endogenous variables carry the steady-state star; parameters and exogenous variables do not.
assert(contains(tex, 'k^{\star}'), 'k starred');
assert(contains(tex, 'x^{\star}'), 'x starred');
assert(contains(tex, 'a^{\star}'), 'a starred');
assert(~contains(tex, '\delta^{\star}'),      'parameter delta not starred');
assert(~contains(tex, '\rho^{\star}'),        'parameter rho not starred');
assert(~contains(tex, '\varepsilon^{\star}'), 'exogenous e not starred');
assert(contains(tex, '\delta') && contains(tex, '\varepsilon'), 'parameter/exogenous texnames still rendered');

% A power of an endogenous variable must star the base with invisible delimiters, never an
% invalid double superscript (k^{\star}^{...}).
mp = modBuilder();
mp.add('y', 'y = k(-1)^alpha');
mp.add('k', 'k = (1-delta)*k(-1) + y');
mp.parameter('alpha', 0.33, 'texname', '\alpha');
mp.parameter('delta', 0.025, 'texname', '\delta');
texp = mp.tex_steady_state_system();
assert(contains(texp, '\left. k^{\star} \right.^{\alpha}'), 'starred base under a power uses invisible delimiters');
assert(~contains(texp, 'star}^{'), 'no double superscript on a starred base');

% Writing to a file produces exactly the returned string.
fname = [tempname '.tex'];
m.tex_steady_state_system(fname);
assert(isfile(fname), 'tex_steady_state_system wrote the file');
written = fileread(fname);
delete(fname);
assert(strcmp(written, tex), 'file content matches the returned string');

% End-to-end: the produced LaTeX must actually compile. Skipped (not failed) where no LaTeX
% toolchain is available, so the suite stays portable.
if system('command -v pdflatex >/dev/null 2>&1') == 0
    td = tempname;
    mkdir(td);
    cleanup = onCleanup(@() rmdir(td, 's'));   %#ok<NASGU>
    doc = ['\documentclass{article}' newline ...
           '\usepackage{amsmath}'   newline ...
           '\begin{document}'       newline ...
           tex                      newline ...
           '\end{document}'         newline];
    texfile = fullfile(td, 'steady.tex');
    fid = fopen(texfile, 'w');
    fprintf(fid, '%s', doc);
    fclose(fid);
    [st, out] = system(sprintf('pdflatex -interaction=nonstopmode -halt-on-error -output-directory ''%s'' ''%s''', td, texfile));
    assert(st == 0, sprintf('produced LaTeX failed to compile:\n%s', out));
    assert(isfile(fullfile(td, 'steady.pdf')), 'pdflatex reported success but produced no PDF');
else
    fprintf('tex-ss/t01.m: pdflatex not found, skipping the LaTeX compile check\n');
end

fprintf('tex-ss/t01.m: tex_steady_state_system OK\n');
