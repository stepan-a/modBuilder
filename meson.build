project('modBuilder-unit-tests', 'cpp')

matlab_path = get_option('matlab_path')

if matlab_path == ''
  error('You must provide the MATLAB path via -Dmatlab_path=/path/to/matlab')
endif

matlab = find_program(matlab_path, required: true)

subdir('tests')