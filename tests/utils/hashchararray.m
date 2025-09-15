function hash = hashchararray(A, algo)
    % Compare two text files.
    %
    % INPUTS:
    % - A            [char]     m×n array
    % - algo         [char]     1×p array, algorithm used to compute the hash. Available values are 'md5sum', 'sha1sum', 'sha256sum', 'sha512sum'
    %
    % OUTPUTS:
    % - hash         [char]     1×q array
    %
    % REMARKS:
    % Default algorithm is md5sum.

    if nargin<2
        algo = 'md5sum';
    end

    tmpfilename = tempname(pwd);

    fid = fopen(tmpfilename, 'w');
    fprintf(fid, '%s', A);
    fclose(fid);

    [status, cmdout] = system(sprintf('%s "%s"', algo, tmpfilename));

    if status ~= 0
        error('Failed to compute the hash.');
    end

    hash = strtok(cmdout);
    
    delete(tmpfilename)
    
end

