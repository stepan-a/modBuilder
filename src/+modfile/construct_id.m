function id = construct_id(filename, line)
% A key identifying one directive construct, unique across the files of a reading.
%
% INPUTS:
% - filename   [char]     1×n array, the file the directive is written in
% - line       [double]   scalar, its line in that file
%
% OUTPUTS:
% - id         [double]   scalar key
%
% EXAMPLES:
% modfile.construct_id('model.mod', 12)
%
% REMARKS:
% - The line alone will not do once @#include is in play: an included file starts again
%   at line 1, so a directive in it sits at the same line as one in the includer. Two
%   constructs sharing a key are grouped as one when the script is emitted, and forcing a
%   branch of one forces the other.
% - The key is a hash of the path, not a position in the order the files were met. It has
%   to be the same when the file is read again with a branch forced, and forcing can
%   change which files an @#include brings in, so anything counted during the scan would
%   shift under the keys already handed out.
% - The hash is folded into 26 bits and the line into the low 20, which keeps the key an
%   exact double. Two paths would have to hash alike AND carry a directive on the same
%   line to collide.
    arguments
        filename (1,:) char
        line     (1,1) double
    end

    h = 0;
    for i = 1:numel(filename)
        h = mod(h * 31 + double(filename(i)), 67108864);
    end
    id = h * 1048576 + line;
end
