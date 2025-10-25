project('modBuilder-unit-tests', 'cpp')

matlab_path = get_option('matlab_path')

if matlab_path == ''
  error('You must provide the MATLAB path via -Dmatlab_path=/path/to/matlab')
endif

matlab = find_program(matlab_path, required: true)

subdir('tests')

# Documentation build target (optional)
sphinx_build = find_program('sphinx-build', required: false)

if sphinx_build.found()
  run_target('docs',
    command: [
      sphinx_build,
      '-b', 'html',
      meson.project_source_root() / 'docs/source',
      meson.project_source_root() / 'docs/build/html'
    ]
  )

  # Clean documentation build directory
  run_target('docs-clean',
    command: [
      'rm', '-rf',
      meson.project_source_root() / 'docs/build'
    ]
  )

  message('Documentation targets available:')
  message('  ninja docs       - Build HTML documentation')
  message('  ninja docs-clean - Clean documentation build directory')
else
  message('sphinx-build not found. Documentation target not available.')
  message('Install with: pip install -r docs/requirements.txt')
endif