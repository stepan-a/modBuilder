function names = dynare_reserved_function_names()
% Canonical list of Dynare-recognised function and operator names.
%
% OUTPUTS:
% - names   [cell]   1×n array of row char arrays, the reserved names that
%                    must not be used as user symbols (parameters, exogenous
%                    or endogenous variables).
%
% REMARKS:
% - This is the single source of truth for the reserved set. modBuilder
%   stores it in its DYNARE_RESERVED_NAMES constant (used by getsymbols to
%   filter out functions when extracting symbols from an equation). The ast
%   class stores it in its RESERVED_FNAMES constant (used by parse_atom to
%   recognise function-call atoms).
% - The list includes STEADY_STATE. The ast parser handles STEADY_STATE
%   with a dedicated branch before the membership test, so it never produces
%   a 'call' node for it.
    names = {'log', 'log10', 'ln', 'exp', 'sqrt', 'cbrt', 'abs', 'sign', 'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'sinh', 'cosh', 'tanh', 'asinh', 'acosh', 'atanh', 'min', 'max', 'normcdf', 'normpdf', 'erf', 'diff', 'adl', 'EXPECTATIONS', 'STEADY_STATE'};
end
