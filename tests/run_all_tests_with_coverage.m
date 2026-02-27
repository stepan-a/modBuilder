function run_all_tests_with_coverage()
%RUN_ALL_TESTS_WITH_COVERAGE Run all tests and generate coverage reports.
%
%   Runs the full test suite via the AllTests parametrized test class,
%   collects code coverage for src/ using CodeCoveragePlugin, and
%   generates Cobertura XML and JUnit XML reports at the repository root.

    import matlab.unittest.TestRunner
    import matlab.unittest.TestSuite
    import matlab.unittest.plugins.CodeCoveragePlugin
    import matlab.unittest.plugins.XMLPlugin
    import matlab.unittest.plugins.codecoverage.CoberturaFormat

    rootdir = fileparts(pwd);
    srcdir = fullfile(rootdir, 'src');

    % Build test suite from the parametrized AllTests class
    suite = TestSuite.fromClass(?AllTests);
    fprintf('Discovered %d tests.\n\n', numel(suite));

    % Collect all .m source files explicitly (forFolder with
    % IncludingSubfolders can truncate coverage on large classdef files).
    srcfiles = dir(fullfile(srcdir, '**', '*.m'));
    filepaths = arrayfun(@(f) fullfile(f.folder, f.name), srcfiles, ...
        'UniformOutput', false);

    % Configure runner with text output, coverage, and JUnit reporting
    runner = TestRunner.withTextOutput;
    runner.addPlugin(CodeCoveragePlugin.forFile(filepaths, ...
        'Producing', CoberturaFormat(fullfile(rootdir, 'coverage.xml'))));
    runner.addPlugin(XMLPlugin.producingJUnitFormat( ...
        fullfile(rootdir, 'test-results.xml')));

    % Run all tests
    results = runner.run(suite);

    % Display summary table
    fprintf('\n');
    disp(table(results));

    % Fail the CI job if any test failed
    nfailed = nnz([results.Failed]);
    if nfailed > 0
        error('modBuilder:testFailure', '%d test(s) failed.', nfailed);
    end
end
