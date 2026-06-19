% Tests for autoDiff1 operator type errors

% mpower (^) with an unsupported right operand (char)
thrown = false;
try
    autoDiff1(2) ^ 'x';
catch ME
    thrown = strcmp(ME.identifier, 'autoDiff1:mpower:typeError');
end
assert(thrown, 'Expected autoDiff1:mpower:typeError for ^ with a char operand.');

% comparison operator with an unsupported operand (cell)
thrown = false;
try
    autoDiff1(2) < {1};
catch ME
    thrown = strcmp(ME.identifier, 'autoDiff1:compare_op:badType');
end
assert(thrown, 'Expected autoDiff1:compare_op:badType for a comparison with a cell.');
