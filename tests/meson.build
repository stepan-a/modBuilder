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
  'ad/t01',
  'ad/t02',
  'ad/t03',
  'ad/t04',
  'ad/t05',
  'ad/t06',
  'ad/t07',
  'ad/t08',
  'ad/t09',
  'ad/t10',
  'ad/t11',
  'ad/t12',
  'ad/t13',
  'ad/t14',
  'ad/t15',
  'ad/t16',
  'ad/t17',
  'ad/t18',
  'ad/t19',
  'ad/t20',
  'ad/t21',
  'ad/t22',
  'ad/t23',
  'ad/t24',
  'ad/t25',
  'ad/t26',
  'ad/t27',
  'ad/t28',
  'ad/t29',
  'ad/t30',
  'ad/t31',
  'ad/t32'
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