% Error identifiers raised by the .mod reader and the macro engine.
%
% The reader has to fail loudly and specifically: a .mod file it cannot handle must say
% which construct and why, never build a different model quietly.

addpath ../utils

% --- Lexical layer ---------------------------------------------------------------------
assert_id(@() modfile.strip_comments('var x $tex;'),                'modfile:strip_comments:unterminatedTexName');
assert_id(@() modfile.strip_comments('var a; /* never closed'),     'modfile:strip_comments:unterminatedComment');
assert_id(@() modfile.strip_comments('var x (long_name=''oops);'),  'modfile:strip_comments:unterminatedString');
assert_id(@() modfile.split_statements('var a; trailing text'),     'modfile:split_statements:trailingText');
assert_id(@() modfile.split_statements('model; y = 1;'),            'modfile:split_statements:unterminatedBlock');
assert_id(@() modfile.parse_declaration('a 1b', 'var'),             'modfile:parse_declaration:badSymbol');

% --- Model block -----------------------------------------------------------------------
assert_id(@() modfile.parse_model_block('y = a = b;'),              'modfile:parse_model_block:badEquation');
assert_id(@() modfile.parse_model_block('[name = ''y'']'),          'modfile:parse_model_block:danglingTag');
assert_id(@() modfile.parse_model_block('#1bad = a;'),              'modfile:parse_model_block:badLocalVariable');
assert_id(@() modfile.parse_steady_state_model('y;'),               'modfile:parse_steady_state_model:badAssignment');
assert_id(@() modfile.parse_initval('1 = 2;'),                      'modfile:parse_initval:badAssignment');

% --- Whole-file reading ----------------------------------------------------------------
source = 't41_reader.mod';
writefile(source, 'var y;\nvarexo e;\nparameters alpha;\nalpha = 0.5;\nmodel;\n[name = ''y'']\ny = alpha*e;\nend;\n');
cleanup = onCleanup(@() delete(source));

assert_id(@() modfile.read(nomodel()),                              'modfile:read:missingModel');
assert_id(@() modfile.read(unsupported()),                          'modfile:read:unsupportedStatement');
assert_id(@() modBuilder('no-such-file.mod'),                       'modBuilder:modBuilder:unknownFile');
assert_id(@() modBuilder(42),                                       'modBuilder:modBuilder:badType');

% --- Macro engine ----------------------------------------------------------------------
env = macro.environment(struct('N', 3));
assert_id(@() macro('1 $ 2'),                                       'macro:tokenise:badCharacter');
assert_id(@() macro('1 +'),                                         'macro:parse:unexpectedEnd');
assert_id(@() macro('[1, 2'),                                       'macro:parse:missingToken');
assert_id(@() macro('Missing').eval(env),                           'macro:eval:undefinedVariable');
assert_id(@() macro('1 + "a"').eval(env),                           'macro:eval_binop:typeError');
assert_id(@() macro('"a"^2').eval(env),                             'macro:eval:typeError');

% --- Macro directives ------------------------------------------------------------------
assert_id(@() modfile.expand_macros(sprintf('@#if true\nyes\n')),   'modfile:expand_macros:unterminatedDirective');
assert_id(@() modfile.expand_macros(sprintf('@#endif\n')),          'modfile:expand_macros:unexpectedDirective');
assert_id(@() modfile.expand_macros(sprintf('@#bogus 1\n')),        'modfile:expand_macros:unsupportedDirective');
assert_id(@() modfile.expand_macros(sprintf('@#define 1x = 2\n')),  'modfile:expand_macros:badDefine');
assert_id(@() modfile.expand_macros(sprintf('@#for i [1]\n@#endfor\n')), 'modfile:expand_macros:badLoop');
assert_id(@() modfile.expand_macros(sprintf('@#define k = 1\nvar y_@{k;\n')), 'modfile:expand_macros:unterminatedEval');
assert_id(@() modfile.resolve_include('nowhere.inc', 'main.mod'),   'modfile:resolve_include:includeNotFound');

fprintf('errors/t41.m: All tests passed\n');

function writefile(name, text)
    fid = fopen(name, 'w');
    fprintf(fid, text);
    fclose(fid);
end

function name = nomodel()
    name = 't41_nomodel.mod';
    fid = fopen(name, 'w');
    fprintf(fid, 'var y;\nvarexo e;\n');
    fclose(fid);
end

function name = unsupported()
    name = 't41_unsupported.mod';
    fid = fopen(name, 'w');
    fprintf(fid, 'var y;\nvarexo e;\nparameters alpha;\nalpha = 0.5;\nmodel;\n[name = ''y'']\ny = alpha*e;\nend;\npredetermined_variables y;\n');
    fclose(fid);
end

function assert_id(thunk, expected)
    threw = false;
    try
        thunk();
    catch e
        threw = true;
        assert(strcmp(e.identifier, expected), ...
               'Expected id "%s", got "%s" (msg: %s)', expected, e.identifier, e.message);
    end
    assert(threw, 'Expected error with id "%s" but no error was thrown.', expected);
end
