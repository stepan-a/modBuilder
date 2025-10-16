classdef autoDiffN
% autoDiffN  First-order automatic differentiation for vector functions
%   Representation for f : R^n -> R^m (here m and n can be different but
%   typical use is m = n). The object stores:
%       x  - column vector (m x 1) of values
%       J  - Jacobian matrix (m x n)
%
%   Construction:
%       a = autoDiffN(x)                     -> treats x as constants, J=zeros(m,n)
%       a = autoDiffN(x,'identity')         -> treat x as independent variables -> J = I_m (n = m)
%       a = autoDiffN(x, J)                 -> explicit Jacobian
%
%   Core operations implemented (elementwise / linear): +, -, .*, ./, * (numeric
%   matrix multiply with autoDiffN), sin, cos, exp, log, power (scalar exponent),
%   subsref (indexing returning sub-vector/element with proper Jacobian).

    properties
        x   % (m x 1) column vector of values
        J   % (m x n) Jacobian matrix
    end

    methods
        function obj = autoDiffN(x, second)
            if nargin == 0
                obj.x = [];
                obj.J = [];
                return
            end
            x = x(:); % force column
            m = numel(x);
            if nargin < 2
                % treat as constants with zero Jacobian (n = 0)
                obj.x = x;
                obj.J = zeros(m, 0);
                return
            end
            if ischar(second) && strcmp(second, 'identity')
                % independent variables: square Jacobian I_m
                obj.x = x;
                obj.J = eye(m);
                return
            end
            % otherwise second is explicit Jacobian
            J = second;
            if isempty(J)
                obj.x = x;
                obj.J = zeros(m, 0);
                return
            end
            % ensure dimensions match
            if size(J,1) ~= m
                error('autoDiffN:BadJacobian', 'Jacobian row count must match length(x).');
            end
            obj.x = x;
            obj.J = J;
        end

        function r = value(obj)
            % Return numeric value x
            r = obj.x;
        end

        function J = jacobian(obj)
            J = obj.J;
        end

        %% Indexing: return sub-vector with corresponding Jacobian rows
        function s = subsref(obj, S)
            if strcmp(S(1).type, '()')
                idx = S(1).subs{1};
                xsub = obj.x(idx);
                Jsub = obj.J(idx, :);
                s = autoDiffN(xsub, Jsub);
                if numel(S) > 1
                    s = subsref(s, S(2:end));
                end
            else
                % dot access or other: fallback to builtin
                s = builtin('subsref', obj, S);
            end
        end

        %% Unary minus
        function q = uminus(o)
            q = autoDiffN(-o.x, -o.J);
        end

        %% Addition / subtraction
        function q = plus(a, b)
            if isnumeric(a)
                a = autoDiffN(a, zeros(numel(a), size(b.J,2)));
            end
            if isnumeric(b)
                b = autoDiffN(b, zeros(numel(b), size(a.J,2)));
            end
            if numel(a.x) ~= numel(b.x)
                error('autoDiffN:SizeMismatch', 'Addition operands must have the same number of rows.');
            end
            % If Jacobians have different n (number of independent vars), pad with zeros
            n = max(size(a.J,2), size(b.J,2));
            Ja = padcols(a.J, n);
            Jb = padcols(b.J, n);
            q = autoDiffN(a.x + b.x, Ja + Jb);
        end

        function q = minus(a, b)
            q = plus(a, uminus(b));
        end

        %% Elementwise multiplication (.*)
        function q = times(a, b)
            if isnumeric(a)
                a = autoDiffN(a, zeros(numel(a(:)), size(b.J,2)));
            end
            if isnumeric(b)
                b = autoDiffN(b, zeros(numel(b(:)), size(a.J,2)));
            end
            if numel(a.x) ~= numel(b.x)
                error('autoDiffN:SizeMismatch', 'Elementwise multiplication requires same sizes.');
            end
            x = a.x .* b.x;
            % J = diag(b.x)*Ja + diag(a.x)*Jb
            n = max(size(a.J,2), size(b.J,2));
            Ja = padcols(a.J, n);
            Jb = padcols(b.J, n);
            J = diag(b.x) * Ja + diag(a.x) * Jb;
            q = autoDiffN(x, J);
        end

        %% Elementwise division (./)
        function q = rdivide(a, b)
            if isnumeric(a)
                a = autoDiffN(a, zeros(numel(a(:)), size(b.J,2)));
            end
            if isnumeric(b)
                b = autoDiffN(b, zeros(numel(b(:)), size(a.J,2)));
            end
            if numel(a.x) ~= numel(b.x)
                error('autoDiffN:SizeMismatch', 'Elementwise division requires same sizes.');
            end
            x = a.x ./ b.x;
            n = max(size(a.J,2), size(b.J,2));
            Ja = padcols(a.J, n);
            Jb = padcols(b.J, n);
            J = (diag(1./b.x) * Ja) - (diag(a.x ./ (b.x.^2)) * Jb);
            q = autoDiffN(x, J);
        end

        %% Matrix multiply with numeric on left or right: A*AD or AD*A
        function q = mtimes(a, b)
            if isa(a, 'double') && isa(b, 'autoDiffN')
                x = a * b.x;
                J = a * b.J;
                q = autoDiffN(x, J);
                return
            elseif isa(a, 'autoDiffN') && isa(b, 'double')
                x = a.x * b;
                J = a.J * b;
                q = autoDiffN(x, J);
                return
            end
            error('autoDiffN:NotImplemented', 'Matrix multiply between two autoDiffN objects is not implemented (use numeric matrices or elementwise operations).');
        end

        %% Power with scalar exponent: o.^p where p numeric scalar
        function q = mpower(o, p)
            if isa(o, 'autoDiffN') && isnumeric(p) && isscalar(p)
                x = o.x .^ p;
                % derivative: p * x.^(p-1) * J
                J = diag(p * (o.x.^(p-1))) * o.J;
                q = autoDiffN(x, J);
                return
            end
            error('autoDiffN:NotImplemented', 'Power implemented only for autoDiffN ^ scalar.');
        end

        %% Elementary vectorized functions
        function q = sin(o)
            q = autoDiffN(sin(o.x), diag(cos(o.x)) * o.J);
        end
        function q = cos(o)
            q = autoDiffN(cos(o.x), diag(-sin(o.x)) * o.J);
        end
        function q = exp(o)
            q = autoDiffN(exp(o.x), diag(exp(o.x)) * o.J);
        end
        function q = log(o)
            q = autoDiffN(log(o.x), diag(1./o.x) * o.J);
        end

    end % methods
end

%% Helper: pad columns of Jacobian to n (add zero columns on right)
function Jout = padcols(Jin, n)
if isempty(Jin)
    Jout = zeros(size(Jin,1), n);
    return
end
c = size(Jin,2);
if c == n
    Jout = Jin;
elseif c < n
    Jout = [Jin, zeros(size(Jin,1), n-c)];
else
    % truncate extra columns (shouldn't normally happen)
    Jout = Jin(:,1:n);
end
end
