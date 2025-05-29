matlab = find_program('matlab', required: true)

listoftests = [
  'rbc/rbc1',
  'rbc/rbc2',
]

foreach t : listoftests
  test(
    t,
    matlab,
    args: ['-batch', 'runtest("' + t + '")'],
    workdir: meson.current_source_dir(),
    timeout: 60
  )
endforeach