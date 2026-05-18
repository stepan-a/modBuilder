classdef autoDiff1
% Dual number class for first‑order derivatives f : R → R

    properties
        x      % double scalar
        dx     % double scalar (derivative)
    end


    methods

        function o = autoDiff1(x, dx)
            if nargin<2
                dx = 1;
            end

            o.x = x;
            o.dx = dx;
        end % function

        %
        % Arithmetics
        %

        function q = plus(o, p)
        % Overload the + binary operator.
            [o, p] = autoDiff1.convert(o, p);
            q = autoDiff1(o.x + p.x, o.dx + p.dx);
        end % function

        function q = minus(o, p)
        % Overload the -  binary operator.
            [o, p] = autoDiff1.convert(o, p);
            q = autoDiff1(o.x - p.x, o.dx - p.dx);
        end % function

        function q = mtimes(o, p)
        % Overload the * binary operator.
            [o, p] = autoDiff1.convert(o, p);
            q = autoDiff1(o.x*p.x, o.dx*p.x + o.x*p.dx);
        end % function

        function q = mrdivide(o, p)
            % Overload the / binary operator.
            [o, p] = autoDiff1.convert(o, p);
            q = autoDiff1(o.x/p.x, (o.dx*p.x - p.dx*o.x)/(p.x^2));
        end % function

        function q = mpower(o, p)
        % Overload the ^ binary operator.
            if isa(o, 'autoDiff1') && isnumeric(p)
                if p == 0
                    % x^0 ≡ 1 with identically-zero derivative; the
                    % general formula p*o.dx*o.x^(p-1) collapses to the
                    % indeterminate 0*Inf at o.x = 0 and must be short-
                    % circuited.
                    q = autoDiff1(1, 0);
                else
                    q = autoDiff1(o.x^p, p*o.dx*o.x^(p-1));
                end
            elseif isnumeric(o) && isa(p, 'autoDiff1')
                if o>0
                    tmp = o^p.x;
                    q = autoDiff1(tmp, log(o)*tmp*p.dx);
                else
                    error('autoDiff1:mpower:nonPositiveBase', ...
                          'Base must be positive when the exponent is differentiable (got %g).', o);
                end
            elseif isa(o, 'autoDiff1') && isa(p, 'autoDiff1')
                if o.x>0
                    tmp = o.x^p.x;
                    q = autoDiff1(tmp, tmp*(p.dx*log(o.x)+p.x*o.dx/o.x ));
                else
                    error('autoDiff1:mpower:nonPositiveBase', ...
                          'Base must be positive when both operands are differentiable (got %g).', o.x);
                end
            else
                error('autoDiff1:mpower:typeError', ...
                      'Unsupported operand types for ^.');
            end
        end % function

        function q = uminus(o)
        % Overload the unary minus operator.
            q = autoDiff1(-o.x, -o.dx);
        end

        function q = uplus(o)
        % Overload the unary plus operator.
            q = o;
        end

        %
        % Special mathematical functions
        %

        function q = exp(o)
        % Overload the exponential function.
            tmp = exp(o.x);
            q = autoDiff1(tmp, tmp*o.dx);
        end % function

        function q = log(o)
        % Overload the natural logarithm function.
            if o.x>0
                q = autoDiff1(log(o.x), o.dx/o.x);
            else
                error('autoDiff1:log:domain', ...
                      'log argument must be positive (got %g).', o.x);
            end
        end % function

        function q = log10(o)
        % Overload the base 10 logarithm function.
            if o.x>0
                q = autoDiff1(log10(o.x), o.dx/(o.x*log(10)));
            else
                error('autoDiff1:log10:domain', ...
                      'log10 argument must be positive (got %g).', o.x);
            end
        end % function

        function q = ln(o)
        % Overload the natural logarithm function (Dynare-style alias for log).
        % Dispatched here by ast.eval when an equation contains ln(...): the
        % parser produces a 'call' node with name 'ln' (listed in
        % dynare_reserved_function_names), and ast.eval feval's it on the
        % autoDiff1 operand. Without this method the call would fall through
        % to a missing built-in and error out.
            q = log(o);
        end % function

        function q = sqrt(o)
        % Overload the square root function.
        % At o.x = 0 the derivative is ±Inf via IEEE division by zero;
        % the Newton solvers catch a non-finite derivative on the next
        % iteration and raise a structured error.
            if o.x>=0
                tmp = sqrt(o.x);
                q = autoDiff1(tmp, o.dx/(2*tmp));
            else
                error('autoDiff1:sqrt:domain', ...
                      'sqrt argument must be non-negative (got %g).', o.x);
            end
        end % function

        function q = cbrt(o)
        % Overload the cubic root function.
        % Domain is all reals; nthroot handles negatives natively. At
        % o.x = 0 the derivative is ±Inf via IEEE division by zero; the
        % Newton solvers catch a non-finite derivative on the next
        % iteration and raise a structured error.
            tmp = nthroot(o.x, 3);
            q = autoDiff1(tmp, o.dx/(3*tmp*tmp));
        end % function

        function q = sign(o)
        % Overload the sign function.
            if abs(o.x)>0

                if o.x>0
                    q = autoDiff1(1, 0);
                else
                    q = autoDiff1(-1, 0);
                end
            else
                % The generalized derivative (distribution theory) should be:
                %
                %      2δ(x)⋅dx
                %
                % where δ(x) is the Dirac function. In practice instead of throwing an arror (below) we could use a
                % smooth approximation of sign(x) with the hyperbolic tangent:
                %
                %      sign(x) ≈ tanh(k⋅x)
                %
                % where k is a large positive constant (e.g. 1000). The first derivative, for all x ∈ R, would be given
                % by the hyperbolic secant:
                %
                %      k⋅sech(k⋅x)⋅dx
                %
                % where the hyperbolic secant is defined as the the inverse of the hyperbolic cosine:
                %
                %      sech(x) = 1/cosh(x)
                %
                % For the purpose of the toolbox (finding the zero of a static equation for the steady state) we probably
                % do not need such an approximation. Note that Dynare will return 0 if x is equal to 0 (see the reference
                % manual).
                error('autoDiff1:sign:nonDifferentiable', ...
                      'sign is not differentiable at x = 0.')
            end
        end % function

        function q = abs(o)
        % Overload the absolute value function.
        % At o.x = 0 the chain-rule factor sign(0)*o.dx is 0*o.dx = 0,
        % which is the standard sub-gradient choice (and consistent with
        % Dynare's convention that sign(0) = 0). No branch needed.
            q = autoDiff1(abs(o.x), sign(o.x)*o.dx);
        end % function

        function q = sin(o)
        % Overload the sine function.
            q  = autoDiff1(sin(o.x), cos(o.x)*o.dx);
        end % function

        function q = cos(o)
        % Overload the cosine function.
            q = autoDiff1(cos(o.x), -sin(o.x)*o.dx);
        end % function

        function q = tan(o)
        % Overload the tangent function.
        % Asymptote detection thresholds the actual denominator
        % cos(o.x) with an eps-scaled tolerance so the test stays
        % meaningful far from the origin (the modular check
        % (o.x - pi/2)/pi loses precision at large o.x).
            c = cos(o.x);
            if abs(c) > eps(o.x) * 1e2
                q = autoDiff1(tan(o.x), o.dx/c^2);
            else
                error('autoDiff1:tan:asymptote', ...
                      'tan(x) has an asymptote near x = %g.', o.x);
            end
        end % function

        function q = asin(o)
        % Overload the inverse sine function.
        % At |o.x| = 1 the value asin(±1) = ±pi/2 is well-defined and
        % the derivative is ±Inf via IEEE division by zero; the Newton
        % solvers catch a non-finite derivative on the next iteration.
            if abs(o.x)<=1
                q = autoDiff1(asin(o.x), o.dx/sqrt(1-o.x^2));
            else
                error('autoDiff1:asin:domain', ...
                      'asin argument must satisfy |x| <= 1 (got %g).', o.x);
            end
        end % function

        function q = acos(o)
        % Overload the inverse cosine function.
        % At |o.x| = 1 the value acos(±1) is well-defined (0 or pi) and
        % the derivative is ∓Inf via IEEE division by zero; the Newton
        % solvers catch a non-finite derivative on the next iteration.
            if abs(o.x)<=1
                q = autoDiff1(acos(o.x), -o.dx/sqrt(1-o.x^2));
            else
                error('autoDiff1:acos:domain', ...
                      'acos argument must satisfy |x| <= 1 (got %g).', o.x);
            end
        end % function

        function q = atan(o)
        % Overload the inverse tangent function.
            q = autoDiff1(atan(o.x), o.dx/(1+o.x^2));
        end % function

        function q = sinh(o)
        % Overload the hyperbolic sine function.
            q  = autoDiff1(sinh(o.x), cosh(o.x)*o.dx);
        end % function

        function q = cosh(o)
        % Overload the hyperbolic cosine function.
            q = autoDiff1(cosh(o.x), sinh(o.x)*o.dx);
        end % function

        function q = tanh(o)
        % Overload the hyperbolic tangent function.
            tmp = tanh(o.x);
            q = autoDiff1(tmp, (1-tmp^2)*o.dx);
        end % function

        function q = asinh(o)
        % Overload the inverse hyperbolic sine function.
            q  = autoDiff1(asinh(o.x), o.dx/sqrt(1+o.x^2));
        end % function

        function q = acosh(o)
        % Overload the inverse hyperbolic cosine function.
        % At o.x = 1 the value acosh(1) = 0 is well-defined and the
        % derivative is +Inf via IEEE division by zero.
            if o.x>=1
                q = autoDiff1(acosh(o.x), o.dx/sqrt(o.x^2-1));
            else
                error('autoDiff1:acosh:domain', ...
                      'acosh argument must satisfy x >= 1 (got %g).', o.x);
            end
        end % function

        function q = atanh(o)
        % Overload the inverse hyperbolic tangent function.
        % At |o.x| = 1 the function diverges to ±Inf, so the boundary
        % is excluded from the domain.
            if abs(o.x)<1
                q = autoDiff1(atanh(o.x), o.dx/(1-o.x^2));
            else
                error('autoDiff1:atanh:domain', ...
                      'atanh argument must satisfy |x| < 1 (got %g).', o.x);
            end
        end % function

        function q = max(o, p)
        % Overload the max function.
            [o, p] = autoDiff1.convert(o, p);
            if o.x>p.x
                q = autoDiff1(o.x, o.dx);
            elseif o.x<p.x
                q = autoDiff1(p.x, p.dx);
            else
                error('autoDiff1:max:nonDifferentiable', ...
                      'Domain error: non differentiable when both arguments are equal.')
            end
        end % function

        function q = min(o, p)
        % Overload the min function.
            [o, p] = autoDiff1.convert(o, p);
            if o.x>p.x
                q = autoDiff1(p.x, p.dx);
            elseif o.x<p.x
                q = autoDiff1(o.x, o.dx);
            else
                error('autoDiff1:min:nonDifferentiable', ...
                      'Domain error: non differentiable when both arguments are equal.')
            end
        end % function

        function q = normcdf(o, mu, sigma)
        % Overload the normcdf function.
            if nargin<3
                sigma = 1;
            end

            if nargin<2
                mu = 0;
            end

            q = autoDiff1(normcdf(o.x, mu, sigma), normpdf(o.x, mu, sigma)*o.dx);
        end % function

        function q = normpdf(o, mu, sigma)
        % Overload the normpdf function.
            if nargin<3
                sigma = 1;
            end

            if nargin<2
                mu = 0;
            end

            q = autoDiff1(normpdf(o.x, mu, sigma), -(o.x-mu)*normpdf(o.x, mu, sigma)*o.dx/sigma^2);
        end % function

        function q = erf(o)
            % Overload the erf function.
            q = autoDiff1(erf(o.x), (2.0/sqrt(pi))*exp(-o.x^2)*o.dx);
        end % function

        function q = erfc(o)
            % Overload the erfc function.
            q = autoDiff1(erfc(o.x), -(2.0/sqrt(pi))*exp(-o.x^2)*o.dx);
        end % function

        function b = lt(o, p)
        % Overload the < operator.
            b = autoDiff1.compare_op(o, p, @lt);
        end % function

        function b = le(o, p)
        % Overload the <= operator.
            b = autoDiff1.compare_op(o, p, @le);
        end % function

        function b = gt(o, p)
        % Overload the > operator.
            b = autoDiff1.compare_op(o, p, @gt);
        end % function

        function b = ge(o, p)
        % Overload the >= operator.
            b = autoDiff1.compare_op(o, p, @ge);
        end % function

    end

    methods (Static)

        function [a,b] = convert(a, b)
        % Promote a or b to autoDiff1 object if need be.
        %
        % INPUTS:
        % - a     [numeric, autoDiff1]   scalar
        % - b     [numeric, autoDiff1]   scalar
        %
        % OUTPUTS:
        % - a     [autoDiff1]            scalar
        % - b     [autoDiff1]            scalar
            if isnumeric(a)
                a = autoDiff1(a, 0);
            end

            if isnumeric(b)
                b = autoDiff1(b, 0);
            end
        end % function

        function b = compare_op(o, p, op)
        % Helper for comparison operators.
        %
        % INPUTS:
        % - o     [numeric, autoDiff1]   scalar
        % - p     [numeric, autoDiff1]   scalar
        % - op    [function_handle]      comparison operator
        %
        % OUTPUTS:
        % - b     [logical]              result of comparison
            if isa(o, 'autoDiff1') && isa(p, 'autoDiff1')
                b = op(o.x, p.x);
            elseif isa(o, 'autoDiff1') && isnumeric(p)
                b = op(o.x, p);
            elseif isnumeric(o) && isa(p, 'autoDiff1')
                b = op(o, p.x);
            else
                error('autoDiff1:compare_op:badType', 'Type error.')
            end
        end % function

    end % methods

end % classdef
