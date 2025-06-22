matlab = find_program('matlab', required: true)

listoftests = [
  'rbc/rbc1',
  'rbc/rbc2',
  'rbc/rbc3',
  'rbc/rbc4',
  'rbc/rbc5',
  'rbc/rbc7',
  'rbc/rbc8',
  'rbc/rbc9',
  'ar/ar1',
  'ar/ar2',
  'ar/ar3',
  'ar/ar4',
  'ar/ar5',
]

listoffailingtests = [
   'rbc/rbc6'
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

foreach t : listoffailingtests
  test(
    t,
    matlab,
    args: ['-batch', 'runtest("' + t + '")'],
    workdir: meson.current_source_dir(),
    should_fail: true,
    timeout: 60
  )
endforeach