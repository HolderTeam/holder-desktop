gnome.compile_schemas(
  build_by_default: true,
)

help_resources = gnome.compile_resources(
  'holder_linux_help',
  'help.gresource.xml',
  source_dir: meson.project_source_root(),
  c_name: 'holder_linux_help',
  export: true,
  install: false,
)
