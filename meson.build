project('zet-mockup', 'vala', version: '0.1.0')

gnome = import('gnome')

deps = [
  dependency('gtk4'),
  dependency('libadwaita-1'),
  dependency('gtksourceview-5'),
  dependency('gio-2.0'),
  dependency('gee-0.8'),
]

executable(
  'zet-mockup',
  'main.vala',
  dependencies: deps,
  install: false
)
