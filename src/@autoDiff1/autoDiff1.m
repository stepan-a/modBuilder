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
        end

        %
        % Arithmetics
        %

        function q = plus(o, p)
        % Overload the + binary operator.
            [o, p] = autoDiff1.convert(o, p);
            q = autoDiff1(o.x + p.x, o.dx + p.dx);
        end

        function q = minus(o, p)
        % Overload the -  binary operator.
            [o, p] = autoDiff1.convert(o, p);
            q = autoDiff1(o.x - p.x, o.dx - p.dx);
        end

        function q = mtimes(o, p)
        % Overload the * binary operator.
            [o, p] = autoDiff1.convert(o, p);
            q = autoDiff1(o.x*p.x, o.dx*p.x + o.x*p.dx);
        end

        function q = mrdivide(o, p)
            % Overload the / binary operator.
            [o, p] = autoDiff1.convert(o, p);
            q = autoDiff1(o.x/p.x, (o.dx*p.x - p.dx*o.x)/(p.x^2));
        end

        function q = mpower(o, p)
        % Overload the ^ binary operator.
            if isa(o, 'autoDiff1') && isnumeric(p)
                q = autoDiff1(o.x^p, p*o.dx*o.x^(p-1));
            elseif isnumeric(o) && isa(p, 'autoDiff1')
                if o>0
                    tmp = o^p.x;
                    q = autoDiff1(tmp, log(o)*tmp*p.dx);
                else
                    error('Domain error: base must be positive.')
                end
            elseif isa(o, 'autoDiff1') && isa(p, 'autoDiff1')
                if o.x>0
                    tmp = o.x^p.x;
                    q = autoDiff1(tmp, tmp*(p.dx*log(o.x)+p.x*o.dx/o.x ));
                else
                    error('Domain error: base must be positive.')
                end
            end
        end

        %
        % Special mathematical functions
        %

        function q = exp(o)
        % Overload the exponential function.
            tmp = exp(o.x);
            q = autoDiff1(tmp, tmp*o.dx);
        end

        function q = log(o)
        % Overload the natural logarithm function.
            if o.x>0
                q = autoDiff1(log(o.x), o.dx/o.x);
            else
                error('Domain error: argument must be positive.')
            end
        end

        function q = log10(o)
        % Overload the base 10 logarithm function.
            if o.x>0
                q = autoDiff1(log10(o.x), o.dx/(o.x*log(10)));
            else
                error('Domain error: argument must be positive.')
            end
        end

        function q = sqrt(o)
        % Overload the square root function.
            if o.x>0
                tmp = sqrt(o.x);
                q = autoDiff1(tmp, o.dx/(2*tmp));
            else
                error('Domain error: argument must be positive.')
            end
        end

        function q = cbrt(o)
        % Overload the cubic root function.
            if abs(o.x)>0
                tmp = nthroot(o.x, 3);
                q = autoDiff1(tmp, o.dx/(3*tmp*tmp));
            else
                error('Domain error: argument must be nonzero.')
            end
        end

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
                error('Domain error: argument must be nonzero.')
            end
        end

        function q = abs(o)
        % Overlaod the absolute value function.
            if abs(o.x)>0
                q = autoDiff1(abs(o.x), sign(o.x)*o.dx);
            else
                q = autoDiff1(0, NaN); % Should we throw an error instead? We could also consider a smooth approximation.
            end
        end

        function q = sin(o)
        % Overload the sine function.
            q  = autoDiff1(sin(o.x), cos(o.x)*o.dx);
        end

        function q = cos(o)
        % Overload the cosine function.
            q = autoDiff1(cos(o.x), -sin(o.x)*o.dx);
        end

        function q = tan(o)
        % Overload the tangent function.
            n = (o.x - pi/2)/pi;
            if abs(n - round(n)) > 1e-15
                q = autoDiff1(tan(o.x), o.dx/cos(o.x)^2);
            else
                error('Domain error: tan(x) has asymptotes if x = pi/2+n*pi (n is an integer).')
            end
        end

        function q = asin(o)
        % Overload the inverse sine function.
            if abs(o.x)<1
                q = autoDiff1(asin(o.x), o.dx/sqrt(1-o.x^2));
            else
                error('Domain error: argument must be less than one in absolute value.')
            end
        end

        function q = acos(o)
        % Overload the inverse cosine function.
            if abs(o.x)<1
                q = autoDiff1(acos(o.x), -o.dx/sqrt(1-o.x^2));
            else
                error('Domain error: argument must be less than one in absolute value.')
            end
        end

        function q = atan(o)
        % Overload the inverse tangent function.
            q = autoDiff1(atan(o.x), o.dx/(1+o.x^2));
        end

        function q = sinh(o)
        % Overload the hyperbolic sine function.
            q  = autoDiff1(sinh(o.x), cosh(o.x)*o.dx);
        end

        function q = cosh(o)
        % Overload the hyperbolic cosine function.
            q = autoDiff1(cosh(o.x), sinh(o.x)*o.dx);
        end

        function q = tanh(o)
        % Overload the hyperbolic tangent function.
            q = autoDiff1(tanh(o.x), (1-tanh(o.x)^2)*o.dx);
        end

        function q = asinh(o)
        % Overload the inverse hyperbolic sine function.
            q  = autoDiff1(asinh(o.x), o.dx/sqrt(1+o.x^2));
        end

        function q = acosh(o)
        % Overload the inverse hyperbolic cosine function.
            if o.x>1
                q = autoDiff1(acosh(o.x), o.dx/sqrt(o.x^2-1));
            else
                error('Domain error: argument must be greater than 1.')
            end
        end

        function q = atanh(o)
        % Overload the inverse hyperbolic tangent function.
            if abs(o.x)<1
                q = autoDiff1(atanh(o.x), o.dx/(1-o.x^2));
            else
                error('Domain error: argument must be smaller than 1.')
            end
        end

        function q = max(o, p)
        % Overload the max function.
            if o.x>p.x
                q = autoDiff1(o.x, o.dx);
            elseif o.x<p.x
                q = autoDiff1(p.x, p.dx);
            else
                error('Domain error: non differentiable when both arguments are equal.')
            end
        end

        function q = min(o, p)
        % Overload the min function.
            if o.x>p.x
                q = autoDiff1(p.x, p.dx);
            elseif o.x<p.x
                q = autoDiff1(o.x, o.dx);
            else
                error('Domain error: non differentiable when both arguments are equal.')
            end
        end

        function q = normcdf(o, mu, sigma)
        % Overload the normcdf function.
            if nargin<3
                sigma = 1;
            end
            if nargin<2
                mu = 0;
            end
            q = autoDiff1(normcdf(o.x, mu, sigma), normpdf(o.x, mu, sigma)*o.dx/sigma);
        end

        function q = normpdf(o, mu, sigma)
        % Overload the normpdf function.
            if nargin<3
                sigma = 1;
            end
            if nargin<2
                mu = 0;
            end
            q = autoDiff1(normpdf(o.x, mu, sigma), -(o.x-mu)*normpdf(o.x, mu, sigma)*o.dx/sigma^2);
        end

        function q = erf(o)
            % Overload the erf function.
            q = autoDiff1(erf(o.x), (2.0/sqrt(pi))*exp(-o.x^2)*o.dx);
        end

        function q = erfc(o)
            % Overload the erf function.
            q = autoDiff1(erfc(o.x), -(2.0/sqrt(pi))*exp(-o.x^2)*o.dx);
        end

        function b = lt(o, p)
        % Overload the < operator.
            if isa(o, 'autoDiff1') && isa(p, 'autoDiff1')
                b = o.x<p.x;
            elseif isa(o, 'autoDiff1') && isnumeric(p)
                b = o.x<p;
            elseif isnumeric(o) && isa(p, 'autoDiff1')
                b = o<p.x;
            else
                error('Type error.')
            end
        end

        function b = le(o, p)
        % Overload the <= operator.
            if isa(o, 'autoDiff1') && isa(p, 'autoDiff1')
                b = o.x<=p.x;
            elseif isa(o, 'autoDiff1') && isnumeric(p)
                b = o.x<=p;
            elseif isnumeric(o) && isa(p, 'autoDiff1')
                b = o<=p.x;
            else
                error('Type error.')
            end
        end

        function b = gt(o, p)
        % Overload the > operator.
            if isa(o, 'autoDiff1') && isa(p, 'autoDiff1')
                b = o.x>p.x;
            elseif isa(o, 'autoDiff1') && isnumeric(p)
                b = o.x>p;
            elseif isnumeric(o) && isa(p, 'autoDiff1')
                b = o>p.x;
            else
                error('Type error.')
            end
        end

        function b = ge(o, p)
        % Overload the >= operator.
            if isa(o, 'autoDiff1') && isa(p, 'autoDiff1')
                b = o.x>=p.x;
            elseif isa(o, 'autoDiff1') && isnumeric(p)
                b = o.x>=p;
            elseif isnumeric(o) && isa(p, 'autoDiff1')
                b = o>=p.x;
            else
                error('Type error.')
            end
        end

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
        end

    end % methods

end % classdef
