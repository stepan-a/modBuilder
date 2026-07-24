function [b, differences] = modiff(f1, f2)
% Compare two text files.
%
% INPUTS:
% - f1            [char]     1×n   name of the first text file
% - f2            [char]     1×m   name of the second text file
%
% OUTPUTS:
% - b             [logical]  scalar, true iff the two files are identical
% - differences   [cell]     stores the differences betwen f1 and f2
%
% REMARKS:
% The routine displays the differences if any.

b = true;

% Read the two files
file1 = fileread(f1);
file2 = fileread(f2);

lines1 = splitlines(file1);
lines2 = splitlines(file2);

% Count and check the number of lines in each file. Report the mismatch
% explicitly: files differing only in trailing empty lines produce no
% per-line difference below, and the test would otherwise fail with no
% diagnostic at all.
if not(length(lines1)==length(lines2))
    b = false;
    fprintf('Line-count mismatch: %d lines in %s, %d lines in %s.\n', length(lines1), f1, length(lines2), f2);
end

n = max(length(lines1), length(lines2));

differences = {};

% Compare each line
for i = 1:n
    line1 = '';
    line2 = '';
    if i <= length(lines1)
        line1 = lines1{i};
    end
    if i <= length(lines2)
        line2 = lines2{i};
    end
    if ~strcmp(line1, line2)
        differences{end+1} = sprintf('Line %d:\nFile n°1: %s\nFile n°2: %s\n', i, line1, line2);
    end
end

% Display differences
if not(isempty(differences))
    b = false;
    fprintf('Differences found:\n\n');
    fprintf('%s\n', differences{:});
end
