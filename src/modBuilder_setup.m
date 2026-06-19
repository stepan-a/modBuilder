function modBuilder_setup()
% modBuilder_setup  Configure MATLAB's path for modBuilder.
%
% Idempotent. Adds, in order:
%
%   1. The src/ directory containing the modBuilder class and its
%      companions (@ast, @autoDiff1, @bytag, +solvers, ...). This is the
%      directory that hosts this very function, so it is always added
%      regardless of how the caller invoked the helper.
%
%   2. src/missing/math/ unconditionally. It supplies Dynare-style
%      aliases (ln, ...) that MATLAB does not provide in any toolbox.
%
%   3. src/missing/stats/ only when normcdf / normpdf are not already
%      resolvable. It holds polyfills used by some models; when the
%      Statistics Toolbox is installed the canonical implementations are
%      kept. Availability is probed with which() rather than license(),
%      because a license may be grantable for a toolbox that is not
%      actually installed (e.g. on CI runners), in which case license()
%      reports the toolbox as present while the functions remain undefined.
%
% USAGE:
%
%     run('/path/to/modBuilder/src/modBuilder_setup.m')   % first time
%
%   or, once src/ is on the path:
%
%     modBuilder_setup()
%
% SEE ALSO: dynare_reserved_function_names.

    here = fileparts(mfilename('fullpath'));

    addpath(here);
    addpath(fullfile(here, 'missing', 'math'));

    if isempty(which('normcdf')) || isempty(which('normpdf'))
        addpath(fullfile(here, 'missing', 'stats'));
    end
end
