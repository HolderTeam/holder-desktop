project('holder-linux', 'vala', version: '0.1.0')

gnome = import('gnome')

subdir('data')

deps = [
  dependency('gtk4'),
  dependency('libadwaita-1'),
  dependency('gtksourceview-5'),
  dependency('libspelling-1'),
  dependency('gio-2.0'),
  dependency('gee-0.8'),
  dependency('libsoup-3.0'),
  dependency('json-glib-1.0'),
  dependency('vte-2.91-gtk4'),
]

sources = [
  'main.vala',
  'src/app.vala',
  'src/models/models.vala',
  'src/services/core_interfaces.vala',
  'src/services/app_settings.vala',
  'src/utils/text_utils.vala',
  'src/views/sidebar.vala',
  'src/views/ai_panel.vala',
  'src/views/preferences_dialog.vala',
  'src/views/flowboard_pane.vala',
  'src/views/toolbox.vala',
  'src/services/ui_adapters.vala',
  'src/views/workspace_pane.vala',
  'src/controllers/main_controller.vala',
  'src/controllers/ai_run_controller.vala',
  'src/controllers/flowboard_controller.vala',
  'src/services/discovery.vala',
  'src/services/api_client.vala',
  'src/views/window.vala',
]

executable(
  'holder-desktop',
  sources,
  dependencies: deps,
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test_exe = executable(
  'holder-linux-tests',
  [
    'src/utils/text_utils.vala',
    'tests/text_utils_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-tests', test_exe)

ai_controller_test_exe = executable(
  'holder-linux-ai-controller-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/ai_run_fakes.vala',
    'src/models/models.vala',
    'src/services/core_interfaces.vala',
    'src/controllers/ai_run_controller.vala',
    'tests/ai_run_controller_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-ai-controller-tests', ai_controller_test_exe)

main_controller_test_exe = executable(
  'holder-linux-main-controller-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'src/models/models.vala',
    'src/services/core_interfaces.vala',
    'src/utils/text_utils.vala',
    'src/controllers/main_controller.vala',
    'tests/main_controller_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-main-controller-tests', main_controller_test_exe)

api_client_test_exe = executable(
  'holder-linux-api-client-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/api_client_fakes.vala',
    'src/models/models.vala',
    'src/services/core_interfaces.vala',
    'src/services/api_client.vala',
    'tests/api_client_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
    dependency('libsoup-3.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-api-client-tests', api_client_test_exe)

discovery_test_exe = executable(
  'holder-linux-discovery-tests',
  [
    'src/models/models.vala',
    'src/services/core_interfaces.vala',
    'src/services/discovery.vala',
    'tests/discovery_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-discovery-tests', discovery_test_exe)

ui_adapters_test_exe = executable(
  'holder-linux-ui-adapters-tests',
  [
    'src/models/models.vala',
    'src/services/core_interfaces.vala',
    'src/services/ui_adapters.vala',
    'tests/ui_adapters_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('gtksourceview-5'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-ui-adapters-tests', ui_adapters_test_exe)

app_settings_test_exe = executable(
  'holder-linux-app-settings-tests',
  [
    'src/services/app_settings.vala',
    'tests/app_settings_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('libadwaita-1'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-app-settings-tests', app_settings_test_exe)
