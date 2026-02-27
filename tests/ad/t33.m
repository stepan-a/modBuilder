% Test uminus and uplus
x = autoDiff1(3.0);
y = -x;        % uminus
if abs(y.x - (-3.0)) > 1e-12 || abs(y.dx - (-1.0)) > 1e-12
    error('uminus failed')
end
z = +x;        % uplus
if abs(z.x - 3.0) > 1e-12 || abs(z.dx - 1.0) > 1e-12
    error('uplus failed')
end
