% macroarray and macrotuple: the MATLAB values a generated script uses for the ordered
% kinds of the macro language.
%
% They exist because MATLAB natives cannot keep the three cases apart: an array of one
% real is the same double as the real, and a tuple is the same cell as an array holding
% the same elements. Carrying the kind in the type is what lets a generated script answer
% isreal, isarray and istuple the way the macro language does.

addpath ../utils

% --- The three cases a plain cell would confuse ---------------------------------------
one = macroarray(7);
pair = macrotuple(1, 2);
plain = 7;

assert(isa(one, 'macroarray') && ~isa(one, 'macrotuple'), 'A one-element array is an array.');
assert(~(isnumeric(one) && isscalar(one)), 'A one-element array must not pass for a real.');
assert(isnumeric(plain) && isscalar(plain), 'A real is a real.');
assert(isa(pair, 'macrotuple') && ~isa(pair, 'macroarray'), 'A tuple is not an array.');

% Building one from a cell array is an expansion, which is what the class methods do.
items = {'US', 'EA'};
assert(macroarray(items{:}) == macroarray('US', 'EA'), 'A cell expands into the constructor.');

% --- Construction and access ------------------------------------------------------------
a = macroarray('US', 'EA', 'JP');
assert(length(a) == 3, 'length counts the elements.');
assert(~isempty(a) && isempty(macroarray()), 'isempty.');
assert(strcmp(a{1}, 'US') && strcmp(a{end}, 'JP'), 'Braces give an element, and end works.');
assert(isa(a(1:2), 'macroarray') && length(a(1:2)) == 2, 'A range gives back a list.');
assert(isequal(cell(a), {'US', 'EA', 'JP'}), 'cell() gives the plain elements.');

% --- The operators of Dynare's Expressions.cc -------------------------------------------
b = macroarray('EA', 'JP', 'CN');

assert(isequal(cell(a + b), {'US', 'EA', 'JP', 'EA', 'JP', 'CN'}), '+ concatenates.');
assert(isequal(cell(a - b), {'US'}), '- is the set difference.');
assert(isequal(cell(a | b), {'US', 'EA', 'JP', 'CN'}), '| is the union, in order of first appearance.');
assert(isequal(cell(a & b), {'EA', 'JP'}), '& is the intersection, in the left operand''s order.');

product = macroarray(1, 2) * macroarray('x', 'y');
assert(length(product) == 4, 'The Cartesian product has one element per pair.');
assert(isa(product{1}, 'macrotuple'), 'Its elements are tuples.');
assert(isequal(cell(product{1}), {1, 'x'}) && isequal(cell(product{4}), {2, 'y'}), 'Last index varies fastest.');

assert(ismember('EA', a) && ~ismember('FR', a), 'ismember is what "in" asks.');
assert(sum(macroarray(1, 2, 3)) == 6, 'sum over the elements.');

% --- Equality is structural, and by kind ------------------------------------------------
assert(macroarray(1, 2) == macroarray(1, 2), 'Same elements, same order.');
assert(macroarray(1, 2) ~= macroarray(2, 1), 'Order matters.');
assert(macroarray(1, 2) ~= macroarray(1), 'Length matters.');
assert(macrotuple(1, 2) ~= macroarray(1, 2), 'A tuple is not equal to an array.');
assert(macroarray('a') ~= macroarray(1), 'A string is not the number it prints as.');

% Nested lists compare too.
assert(macroarray(macrotuple(1, 'x')) == macroarray(macrotuple(1, 'x')), 'Nested equality.');

% --- Display uses the macro language's own notation --------------------------------------
assert(strcmp(string(a), '[US, EA, JP]'), 'An array prints with brackets.');
assert(strcmp(string(pair), '(1, 2)'), 'A tuple prints with parentheses.');
assert(strcmp(string(macroarray(true, 1.5)), '[true, 1.5]'), 'Booleans print as words.');

% --- The array operators refuse anything else -------------------------------------------
thrown = false;
try
    a + 1; %#ok<VUNUS>
catch ME
    thrown = strcmp(ME.identifier, 'macroarray:badType');
end
assert(thrown, 'Expected macroarray:badType.');

% None of the array operators apply to a tuple.
thrown = false;
try
    pair + pair; %#ok<VUNUS>
catch
    thrown = true;
end
assert(thrown, 'A tuple has no concatenation.');

fprintf('t10_classes.m: All tests passed\n');
