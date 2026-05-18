function y = ln(x)
% Natural logarithm — Dynare-style alias for log.
%
% Dynare-syntax equations may contain ln(...); the ast parser produces a
% 'call' node with name 'ln' (listed in dynare_reserved_function_names).
% ast.eval dispatches such nodes via feval(name, args{:}), but MATLAB has
% no top-level `ln` function, so this shim is required for numeric
% evaluation. For autoDiff1 operands the alias lives on the autoDiff1
% class (forward-mode AD path); both paths thus accept ln(...).
    y = log(x);
end
