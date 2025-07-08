% Test relational operators <

a = autoDiff1(1, 0);
b = autoDiff1(2, 0);
c = 3;

if not(a<b)
    error('Wrong output of overloaded le method (autoDiff1<autoDiff1).')
end

if not(a<c)
    error('Wrong output of overloaded le method (autoDiff1<numeric).')
end

if c<a
    error('Wrong output of overloaded le method (numeric<autoDiff1).')
end
