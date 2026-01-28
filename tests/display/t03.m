% Tests for write() with metadata (printlist2 branches)

m = modBuilder();
m.add('y', 'y = alpha*x + beta*z');
m.add('c', 'c = gamma*y');
m.parameter('alpha', 0.5, 'long_name', 'Capital share', 'texname', '\alpha');
m.parameter('beta', 0.3, 'long_name', 'Elasticity');
m.parameter('gamma', 0.8, 'texname', '\gamma');
m.exogenous('x', 0, 'long_name', 'Technology', 'texname', '\varepsilon_x');
m.exogenous('z', 0);
m.endogenous('y', NaN, 'long_name', 'Output', 'texname', 'Y');
m.endogenous('c', NaN, 'long_name', 'Consumption');

basename = fullfile(tempdir, 'test_metadata_write');

m.write(basename);

% Read the written file and verify metadata declarations
fid = fopen([basename '.mod'], 'r');
content = fread(fid, '*char')';
fclose(fid);
delete([basename '.mod']);

% Check that metadata appears in declarations
assert(contains(content, '$\alpha$'), ...
       'File should contain TeX name for alpha.');
assert(contains(content, 'Capital share'), ...
       'File should contain long_name for alpha.');
assert(contains(content, '$\gamma$'), ...
       'File should contain TeX name for gamma.');
assert(contains(content, 'Technology'), ...
       'File should contain long_name for x.');
assert(contains(content, '$\varepsilon_x$'), ...
       'File should contain TeX name for x.');
assert(contains(content, '$Y$'), ...
       'File should contain TeX name for y.');
assert(contains(content, 'Consumption'), ...
       'File should contain long_name for c.');
