gnome.compile_schemas(
  build_by_default: true,
  depend_files: files('team.holder.Holder.gschema.xml'),
)

install_data(
  'team.holder.Holder.gschema.xml',
  install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas'),
)

install_data(
  'gtksourceview-5/language-specs/holder-markdown.lang',
  install_dir: join_paths(get_option('datadir'), 'gtksourceview-5', 'language-specs'),
)

help_resources = gnome.compile_resources(
  'holder_linux_help',
  'help.gresource.xml',
  source_dir: meson.project_source_root(),
  c_name: 'holder_linux_help',
  export: true,
  install: false,
)
