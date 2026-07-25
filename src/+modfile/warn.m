function warn(varargin)
% Issue a warning with the 'backtrace' state temporarily turned off.
%
% INPUTS:
% - varargin   forwarded verbatim to warning(): (msgid, msg, args, ...)
%
% REMARKS:
% - The reader's warnings are about the file being read, not about the call stack
%   inside the package, so a backtrace only adds noise. This mirrors the private
%   modBuilder.warn_silent, which is not reachable from here.
% - onCleanup restores the prior state even if warning() errors out.
    bt = warning('query', 'backtrace');
    warning('off', 'backtrace');
    restore = onCleanup(@() warning(bt.state, 'backtrace')); %#ok<NASGU>
    warning(varargin{:});
end
