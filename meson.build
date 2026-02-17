project('holder-linux', 'vala', version: '0.1.0')

gnome = import('gnome')

deps = [
  dependency('gtk4'),
  dependency('libadwaita-1'),
  dependency('gtksourceview-5'),
  dependency('gio-2.0'),
  dependency('gee-0.8'),
  dependency('libsoup-3.0'),
  dependency('json-glib-1.0'),
]

sources = [
  'main.vala',
  'src/app.vala',
  'src/models.vala',
  'src/discovery.vala',
  'src/api_client.vala',
  'src/window.vala',
]

executable(
  'holder-linux',
  sources,
  dependencies: deps,
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)
