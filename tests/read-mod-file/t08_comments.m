% Comment stripping must not be fooled by quoted values or TeX names.
%
% examples/sw/sw.mod contains $\delta'$ and $S'$: an apostrophe inside a TeX name. A
% stripper that tracks quotes but not TeX names treats that apostrophe as the start of a
% string and corrupts everything after it. A '%' inside a TeX name and a '//' inside a
% quoted long_name are the mirror cases.

addpath ../utils

% The scanner preserves length, so offsets reported later still point at the source.
raw = sprintf('var a; %% trailing\nvarexo e; // trailing\n/* block\n   comment */\nparameters p;\n');
stripped = modfile.strip_comments(raw);
assert(length(stripped) == length(raw), 'strip_comments must preserve the length.');
assert(count(stripped, newline) == count(raw, newline), 'strip_comments must preserve the line count.');
assert(~contains(stripped, 'trailing'), 'Line comments should be blanked.');
assert(~contains(stripped, 'block'), 'Block comments should be blanked.');
assert(contains(stripped, 'var a;') && contains(stripped, 'varexo e;') && contains(stripped, 'parameters p;'), 'Code should survive.');

% An apostrophe inside a TeX name, a '%' inside a TeX name, and '//' inside a quoted value.
tricky = 'var x $\delta''$ (long_name=''see http://example.org'') y $100\%$;';
assert(strcmp(modfile.strip_comments(tricky), tricky), 'Nothing should be stripped from this line.');

rows = modfile.parse_declaration(modfile.strip_comments(tricky(5:end-1)), 'var');
assert(size(rows,1) == 2, 'Two symbols were declared.');
assert(strcmp(rows{1,1}, 'x') && strcmp(rows{1,2}, '\delta''') && strcmp(rows{1,3}, 'see http://example.org'), 'First symbol read incorrectly.');
assert(strcmp(rows{2,1}, 'y') && strcmp(rows{2,2}, '100\%'), 'Second symbol read incorrectly.');

% A whole file with comments in awkward places still reads.
source = 't08_comments.mod';
fid = fopen(source, 'w');
fprintf(fid, '%% a leading comment\n');
fprintf(fid, 'var y $y$ (long_name=''Output, 50%% of it''); // trailing\n');
fprintf(fid, 'varexo e;\n');
fprintf(fid, '/* a block comment\n   spanning lines */\n');
fprintf(fid, 'parameters alpha;\n');
fprintf(fid, 'alpha = 0.5; %% the share\n');
fprintf(fid, 'model;\n[name = ''y'']\ny = alpha*e; %% the only equation\nend;\n');
fclose(fid);
cleanup = onCleanup(@() delete(source));

m = modBuilder(source);
assert(isequal(m.var(:,1), {'y'}), 'Unexpected endogenous variables.');
assert(strcmp(m.var{1,3}, 'Output, 50% of it'), 'The long_name should keep its percent sign.');
assert(strcmp(m.equations{1,2}, 'y = alpha*e'), sprintf('Unexpected equation: %s', m.equations{1,2}));

% An unterminated TeX name is reported rather than swallowing the rest of the file.
thrown = false;
try
    modfile.strip_comments(sprintf('var x $tex;\nvarexo e;\n'));
catch ME
    thrown = strcmp(ME.identifier, 'modfile:strip_comments:unterminatedTexName');
end
assert(thrown, 'Expected strip_comments:unterminatedTexName.');

thrown = false;
try
    modfile.strip_comments('var a; /* never closed');
catch ME
    thrown = strcmp(ME.identifier, 'modfile:strip_comments:unterminatedComment');
end
assert(thrown, 'Expected strip_comments:unterminatedComment.');

fprintf('t08_comments.m: All tests passed\n');
