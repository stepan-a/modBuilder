% modBuilder.tex_model — render the model equations as a LaTeX align block

m = modBuilder();
m.add('y', 'y = exp(a)*k(-1)^alpha*h^(1-alpha)');
m.add('k', 'k = i + (1-delta)*k(-1)');
m.add('a', 'a = rho*a(-1) + e');
m.add('r_k', 'r_k = alpha*y/k(-1)');   % underscore-named variable, no texname
m.parameter('alpha', 0.33, 'texname', '\alpha');
m.parameter('delta', 0.10, 'texname', '\delta');
m.parameter('rho',   0.95, 'texname', '\rho');
m.exogenous('e', 0, 'texname', '\varepsilon');
m.exogenous('i', 0.2);
m.exogenous('h', 0.3);

tex = m.tex_model();

% Wrapped in a single align environment.
assert(startsWith(strtrim(tex), '\begin{align}'), 'starts with \begin{align}');
assert(endsWith(strtrim(tex),   '\end{align}'),   'ends with \end{align}');

% Each equation renders as an aligned row, dated (current period -> _t, lag -> _{t-1}),
% with declared texnames substituted and parameters left bare.
assert(contains(tex, 'y_t &= e^{a_t}\,k_{t-1}^{\alpha}\,h_t^{1 - \alpha}'), 'CD equation row');
assert(contains(tex, 'k_t &= i_t + \left(1 - \delta\right)\,k_{t-1}'),      'capital accumulation row');
assert(contains(tex, 'a_t &= \rho\,a_{t-1} + \varepsilon_t'),               'AR(1) row');
% An underscore-named variable with no texname is escaped (and still dated): r\_k_t.
assert(contains(tex, 'r\_k_t &= \frac{\alpha\,y_t}{k_{t-1}}'),              'escaped underscore variable row');

% Rows are separated by a LaTeX line break "\\" (two backslashes).
assert(contains(tex, [' \\' newline]), 'rows separated by \\');

% Declaration order is preserved (y before k before a).
assert(strfind_order(tex, {'y_t &=', 'k_t &=', 'a_t &='}), 'rows in declaration order');

% Writing to a file produces exactly the returned string.
fname = [tempname '.tex'];
m.tex_model(fname);
assert(isfile(fname), 'tex_model wrote the file');
written = fileread(fname);
delete(fname);
assert(strcmp(written, tex), 'file content matches the returned string');

% End-to-end: the produced LaTeX must actually compile. Wrap the align block in a
% minimal amsmath document and build it with pdflatex. Skipped (not failed) where no
% LaTeX toolchain is available, so the suite stays portable.
if system('command -v pdflatex >/dev/null 2>&1') == 0
    td = tempname;
    mkdir(td);
    cleanup = onCleanup(@() rmdir(td, 's'));   %#ok<NASGU>
    doc = ['\documentclass{article}' newline ...
           '\usepackage{amsmath}'   newline ...
           '\begin{document}'       newline ...
           tex                      newline ...
           '\end{document}'         newline];
    texfile = fullfile(td, 'model.tex');
    fid = fopen(texfile, 'w');
    fprintf(fid, '%s', doc);
    fclose(fid);
    [st, out] = system(sprintf('pdflatex -interaction=nonstopmode -halt-on-error -output-directory ''%s'' ''%s''', td, texfile));
    assert(st == 0, sprintf('produced LaTeX failed to compile:\n%s', out));
    assert(isfile(fullfile(td, 'model.pdf')), 'pdflatex reported success but produced no PDF');
else
    fprintf('tex-model/t01.m: pdflatex not found, skipping the LaTeX compile check\n');
end

fprintf('tex-model/t01.m: modBuilder.tex_model OK\n');

% Helper: true iff the needles appear in `s` in the given order.
function tf = strfind_order(s, needles)
    tf = true;
    last = 0;
    for k = 1:numel(needles)
        idx = strfind(s, needles{k});
        if isempty(idx) || idx(1) <= last
            tf = false;
            return
        end
        last = idx(1);
    end
end
