project('holder-linux', ['vala', 'c'], version: run_command('cat', 'VERSION', check: true).stdout().strip())

gnome = import('gnome')
datadir = get_option('datadir')

config_data = configuration_data()
config_data.set('HOLDER_VERSION', meson.project_version())
config_data.set('HOLDER_PLATFORM', host_machine.system())

holder_config = configure_file(
  input: 'src/config.vala.in',
  output: 'config.vala',
  configuration: config_data,
)

subdir('data')

test_env = environment()
test_home_dir = meson.current_build_dir() / 'test-home'
test_env.set('GSETTINGS_BACKEND', 'memory')
test_env.set('GSETTINGS_SCHEMA_DIR', meson.current_build_dir() / 'data')
test_env.set('HOLDER_DESKTOP_TEST_PLATFORM', host_machine.system())
test_env.set('XDG_CACHE_HOME', test_home_dir / 'cache')
test_env.set('XDG_CONFIG_HOME', test_home_dir / 'config')
test_env.set('XDG_DATA_HOME', test_home_dir / 'data')
test_env.set('XDG_STATE_HOME', test_home_dir / 'state')
add_test_setup('default', env: test_env, is_default: true)

install_data(
  'data/team.holder.Holder.desktop',
  install_dir: join_paths(datadir, 'applications'),
)

install_data(
  'data/team.holder.Holder.metainfo.xml',
  install_dir: join_paths(datadir, 'metainfo'),
)

install_data(
  'img/holder.jpg',
  install_dir: join_paths(datadir, 'holder-desktop'),
  rename: 'holder.jpg',
)

foreach icon_size : ['16x16', '24x24', '32x32', '48x48', '64x64', '128x128', '256x256', '512x512']
  install_data(
    'data/icons/hicolor' / icon_size / 'apps/team.holder.Holder.png',
    install_dir: join_paths(datadir, 'icons', 'hicolor', icon_size, 'apps'),
  )
endforeach

install_man('man/holder-desktop.1')

deps = [
  dependency('gtk4', version: '>=4.14'),
  dependency('libadwaita-1', version: '>=1.5'),
  dependency('gtksourceview-5'),
  dependency('libspelling-1'),
  dependency('gio-2.0'),
  dependency('gee-0.8'),
  dependency('libsoup-3.0'),
  dependency('json-glib-1.0'),
]

terminal_backend = 'disabled'
if get_option('terminal')
  if host_machine.system() == 'windows'
    terminal_backend = 'windows-external'
  else
    terminal_backend = 'vte'
  endif
endif

if terminal_backend == 'vte'
  deps += dependency('vte-2.91-gtk4')
endif

sources = [
  holder_config,
  'main.vala',
  'src/app.vala',
  'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/models/terminal_session.vala',
  'src/models/toolbox_nav.vala',
  'src/state/app_state.vala',
  'src/state/editor_draft_state.vala',
  'src/state/activity_log.vala',
  'src/services/core_interfaces.vala',
  'src/services/app_settings.vala',
  'src/services/editor_font_style.vala',
  'src/services/editor_recovery_draft_service.vala',
  'src/services/powershell_transcript.vala',
  'src/services/print_service.vala',
  'src/services/git_sync_service.vala',
  'src/services/resources_service.vala',
  'src/services/asset_cache.vala',
  'src/services/update_check.vala',
  'src/utils/text_utils.vala',
  'src/views/sidebar.vala',
  'src/views/ai_panel.vala',
  'src/views/asset_preview_pane.vala',
  'src/views/inline_resource_image_renderer.vala',
  'src/views/preferences_dialog.vala',
  'src/views/search.vala',
  'src/views/flowboard_pane.vala',
  'src/views/components/navigation_breadcrumbs.vala',
  'src/views/components/tool_action_bar.vala',
  'src/views/adapters/local_info.vala',
  'src/views/adapters/window_local_info.vala',
  'src/views/adapters/window_recovery_context.vala',
  'src/views/adapters/window_find_replace_ops.vala',
  'src/views/adapters/window_event_endpoints.vala',
  'src/views/adapters/window_internal_link_navigator.vala',
  'src/views/adapters/window_editor_renderer.vala',
  'src/views/adapters/window_activity_feedback.vala',
  'src/views/adapters/window_actions.vala',
  'src/views/adapters/update_dialog.vala',
  'src/views/adapters/card_action_dialog.vala',
  'src/views/adapters/project_create_dialog.vala',
  'src/views/adapters/recovery_dialog.vala',
  'src/views/adapters/window_sidebar_events.vala',
  'src/views/adapters/window_selection_editor_events.vala',
  'src/views/adapters/window_lifecycle_events.vala',
  'src/views/adapters/window_workspace_events.vala',
  'src/views/adapters/window_state_events.vala',
  'src/views/toolbox.vala',
  'src/views/toolbox/tags_tool_view.vala',
  'src/views/toolbox/tool_shell.vala',
  'src/views/toolbox/tool_adapter.vala',
  'src/views/toolbox/connections_tool_view.vala',
  'src/views/ai_panel/config.vala',
  'src/views/toolbox/debug_tool_view.vala',
  'src/views/toolbox/flowboard_tool_view.vala',
  'src/views/toolbox/git_sync_tool_view.vala',
  'src/views/toolbox/recovery_key_tool_view.vala',
  'src/views/toolbox/resources_tool_view.vala',
  'src/views/toolbox/milestones_tool_view.vala',
  'src/views/toolbox/sharing_tool_view.vala',
  'src/views/toolbox/trash_tool_view.vala',
  'src/services/ui_adapters.vala',
  'src/views/workspace_pane.vala',
  'src/controllers/main.vala',
  'src/controllers/backend_session.vala',
  'src/controllers/main_bootstrap.vala',
  'src/controllers/store_sync.vala',
  'src/controllers/main_overview.vala',
  'src/controllers/main_project_flow.vala',
  'src/controllers/main_card_load.vala',
  'src/controllers/projects.vala',
  'src/controllers/cards.vala',
  'src/controllers/editor_save.vala',
  'src/controllers/search.vala',
  'src/controllers/project_create.vala',
  'src/controllers/share.vala',
  'src/controllers/card_append.vala',
  'src/controllers/search_selection.vala',
  'src/controllers/activity_log.vala',
  'src/controllers/activity_reducer.vala',
  'src/controllers/window_feedback_format.vala',
  'src/controllers/selection_request.vala',
  'src/controllers/selection_intent.vala',
  'src/controllers/selection_intent_orchestrator.vala',
  'src/controllers/explorer_selection.vala',
  'src/controllers/sidebar_data_renderer.vala',
  'src/controllers/sidebar_selection_renderer.vala',
  'src/controllers/selection.vala',
  'src/controllers/selection_transition.vala',
  'src/controllers/window_geometry.vala',
  'src/controllers/workspace_layout.vala',
  'src/controllers/flowboard_presenter.vala',
  'src/controllers/toolbox_breadcrumb.vala',
  'src/controllers/toolbox_event_orchestrator.vala',
  'src/controllers/window_feedback_orchestrator.vala',
  'src/controllers/window_action_binder.vala',
  'src/controllers/window_flowboard_event_binder.vala',
  'src/controllers/ai_threads.vala',
  'src/controllers/ai_run.vala',
  'src/controllers/ai_nudge.vala',
  'src/controllers/ai_panel_event_orchestrator.vala',
  'src/services/uri_launcher.vala',
  'src/views/adapters/print_ui.vala',
  'src/controllers/git_sync_presenter.vala',
  'src/controllers/git_sync.vala',
  'src/controllers/resources.vala',
  'src/controllers/asset_preview.vala',
  'src/controllers/connections.vala',
  'src/controllers/terminal.vala',
  'src/controllers/flowboard.vala',
  'src/controllers/flowboard_context.vala',
  'src/controllers/trash.vala',
  'src/controllers/tool_help.vala',
  'src/controllers/find_replace.vala',
  'src/controllers/app_transition.vala',
  'src/controllers/main_signal_binder.vala',
  'src/controllers/local_info.vala',
  'src/controllers/local_info_flow.vala',
  'src/controllers/local_info_ui.vala',
  'src/controllers/local_info_presenter.vala',
  'src/controllers/recovery.vala',
  'src/controllers/recovery_ui.vala',
  'src/controllers/internal_link.vala',
  'src/controllers/tag_navigation.vala',
  'src/controllers/tag_highlighting.vala',
  'src/controllers/markdown_editing.vala',
  'src/controllers/markdown_links.vala',
  'src/controllers/markdown_resource_images.vala',
  'src/controllers/editor_spellcheck.vala',
  'src/services/discovery.vala',
  'src/services/recovery_service.vala',
  'src/services/http_transport.vala',
  'src/services/parsers/common.vala',
  'src/services/parsers/health.vala',
  'src/services/parsers/projects.vala',
  'src/services/parsers/cards.vala',
  'src/services/parsers/resources.vala',
  'src/services/parsers/trash.vala',
  'src/services/parsers/search.vala',
  'src/services/parsers/ai.vala',
  'src/services/parsers/git.vala',
  'src/services/api_client/core.vala',
    'src/services/api_client/transport.vala',
    'src/services/api_client/ai_stream.vala',
  'src/services/api_client/health.vala',
  'src/services/api_client/projects.vala',
  'src/services/api_client/cards.vala',
  'src/services/api_client/resources.vala',
  'src/services/api_client/trash.vala',
  'src/services/api_client/search.vala',
  'src/services/api_client/ai.vala',
  'src/services/api_client/git.vala',
  'src/views/window.vala',
]

if terminal_backend == 'vte'
  sources += 'src/views/toolbox/terminal_tool_view.vala'
elif terminal_backend == 'windows-external'
  sources += [
    'src/services/windows/hidden_process.c',
    'src/services/windows/powershell_discovery.vala',
    'src/services/windows/terminal_session_store.vala',
    'src/services/windows/windows_terminal_launcher.vala',
    'src/views/toolbox/terminal_tool_view_windows.vala',
  ]
else
  sources += 'src/views/toolbox/terminal_tool_view_disabled.vala'
endif

executable(
  'holder-desktop',
  [sources, help_resources],
  dependencies: deps,
  vala_args: [
    '--target-glib=2.70',
  ],
  gui_app: true,
  install: true,
)

if get_option('tests')
test_exe = executable(
  'holder-linux-tests',
  [
    'src/utils/text_utils.vala',
    'tests/text_utils_test.vala',
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

test('holder-linux-tests', test_exe)

ai_controller_test_exe = executable(
  'holder-linux-ai-controller-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/ai_run_fakes.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/controllers/ai_run.vala',
    'tests/ai_run_controller_test.vala',
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

test('holder-linux-ai-controller-tests', ai_controller_test_exe)

ai_nudge_controller_test_exe = executable(
  'holder-linux-ai-nudge-controller-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'tests/support/main_controller_harness.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/state/editor_draft_state.vala',
    'src/state/activity_log.vala',
    'src/utils/text_utils.vala',
    'src/controllers/main.vala',
    'src/controllers/backend_session.vala',
    'src/controllers/main_bootstrap.vala',
    'src/controllers/store_sync.vala',
    'src/controllers/main_overview.vala',
    'src/controllers/main_project_flow.vala',
    'src/controllers/main_card_load.vala',
    'src/controllers/projects.vala',
    'src/controllers/cards.vala',
    'src/controllers/editor_save.vala',
    'src/controllers/search.vala',
    'src/controllers/ai_threads.vala',
    'src/controllers/activity_reducer.vala',
    'src/controllers/ai_nudge.vala',
    'tests/ai_nudge_controller_test.vala',
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

test('holder-linux-ai-nudge-controller-tests', ai_nudge_controller_test_exe)

main_controller_test_exe = executable(
  'holder-linux-main-controller-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'tests/support/main_controller_harness.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/state/editor_draft_state.vala',
    'src/utils/text_utils.vala',
    'src/controllers/main.vala',
    'src/controllers/backend_session.vala',
    'src/controllers/main_bootstrap.vala',
    'src/controllers/store_sync.vala',
    'src/controllers/main_overview.vala',
    'src/controllers/main_project_flow.vala',
    'src/controllers/main_card_load.vala',
    'src/controllers/projects.vala',
    'src/controllers/cards.vala',
    'src/controllers/editor_save.vala',
    'src/controllers/search.vala',
    'src/controllers/ai_threads.vala',
    'tests/main_controller_test.vala',
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

test('holder-linux-main-controller-tests', main_controller_test_exe)

main_extracted_controllers_test_exe = executable(
  'holder-linux-main-extracted-controllers-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'tests/support/main_controller_harness.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/state/editor_draft_state.vala',
    'src/utils/text_utils.vala',
    'src/controllers/main.vala',
    'src/controllers/backend_session.vala',
    'src/controllers/main_bootstrap.vala',
    'src/controllers/store_sync.vala',
    'src/controllers/main_overview.vala',
    'src/controllers/main_project_flow.vala',
    'src/controllers/main_card_load.vala',
    'src/controllers/projects.vala',
    'src/controllers/cards.vala',
    'src/controllers/editor_save.vala',
    'src/controllers/search.vala',
    'src/controllers/ai_threads.vala',
    'tests/main_extracted_controllers_test.vala',
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

test('holder-linux-main-extracted-controllers-tests', main_extracted_controllers_test_exe)

selection_controller_test_exe = executable(
  'holder-linux-selection-controller-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'tests/support/main_controller_harness.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/state/editor_draft_state.vala',
    'src/utils/text_utils.vala',
    'src/controllers/main.vala',
    'src/controllers/backend_session.vala',
    'src/controllers/main_bootstrap.vala',
    'src/controllers/store_sync.vala',
    'src/controllers/main_overview.vala',
    'src/controllers/main_project_flow.vala',
    'src/controllers/main_card_load.vala',
    'src/controllers/projects.vala',
    'src/controllers/cards.vala',
    'src/controllers/editor_save.vala',
    'src/controllers/search.vala',
    'src/controllers/ai_threads.vala',
    'src/controllers/selection.vala',
    'tests/selection_controller_test.vala',
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

test('holder-linux-selection-controller-tests', selection_controller_test_exe)

editor_recovery_draft_service_test_exe = executable(
  'holder-linux-editor-recovery-draft-service-tests',
  [
    'src/services/editor_recovery_draft_service.vala',
    'tests/editor_recovery_draft_service_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-editor-recovery-draft-service-tests', editor_recovery_draft_service_test_exe)

git_sync_controller_test_exe = executable(
  'holder-linux-git-sync-controller-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/app_settings.vala',
    'src/services/git_sync_service.vala',
    'src/controllers/git_sync.vala',
    'tests/git_sync_controller_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
    dependency('libsoup-3.0'),
    dependency('libadwaita-1'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-git-sync-controller-tests', git_sync_controller_test_exe)

git_sync_presenter_test_exe = executable(
  'holder-linux-git-sync-presenter-tests',
  [
    'src/models/activity_details.vala',
    'src/models/git.vala',
    'src/models/project.vala',
    'src/controllers/git_sync_presenter.vala',
    'tests/git_sync_presenter_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gee-0.8'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-git-sync-presenter-tests', git_sync_presenter_test_exe)

resources_controller_test_exe = executable(
  'holder-linux-resources-controller-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/resources_service.vala',
    'src/controllers/resources.vala',
    'tests/resources_controller_test.vala',
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

test('holder-linux-resources-controller-tests', resources_controller_test_exe)

resources_service_test_exe = executable(
  'holder-linux-resources-service-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/resources_service.vala',
    'tests/resources_service_test.vala',
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

test('holder-linux-resources-service-tests', resources_service_test_exe)

connections_controller_test_exe = executable(
  'holder-linux-connections-controller-tests',
  [
    'tests/support/main_controller_fakes.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/app_settings.vala',
    'src/controllers/connections.vala',
    'tests/connections_controller_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
    dependency('libadwaita-1'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-connections-controller-tests', connections_controller_test_exe)

connections_tool_view_test_exe = executable(
  'holder-linux-connections-tool-view-tests',
  [
    'tests/support/main_controller_fakes.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/models/toolbox_nav.vala',
    'src/services/core_interfaces.vala',
    'src/services/app_settings.vala',
    'src/utils/text_utils.vala',
    'src/controllers/connections.vala',
    'src/views/toolbox/tool_adapter.vala',
    'src/views/toolbox/connections_tool_view.vala',
    'tests/connections_tool_view_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
    dependency('libadwaita-1'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-connections-tool-view-tests', connections_tool_view_test_exe)

terminal_controller_test_exe = executable(
  'holder-linux-terminal-controller-tests',
  [
    'src/controllers/terminal.vala',
    'tests/terminal_controller_test.vala',
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

test('holder-linux-terminal-controller-tests', terminal_controller_test_exe)

powershell_transcript_test_exe = executable(
  'holder-linux-powershell-transcript-tests',
  [
    'src/models/terminal_session.vala',
    'src/services/powershell_transcript.vala',
    'tests/powershell_transcript_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-powershell-transcript-tests', powershell_transcript_test_exe)

windows_terminal_services_test_exe = executable(
  'holder-linux-windows-terminal-services-tests',
  [
    'src/services/windows/hidden_process.c',
    'src/models/terminal_session.vala',
    'src/services/app_settings.vala',
    'src/services/powershell_transcript.vala',
    'src/services/windows/powershell_discovery.vala',
    'src/services/windows/terminal_session_store.vala',
    'src/services/windows/windows_terminal_launcher.vala',
    'tests/windows_terminal_services_test.vala',
  ],
  dependencies: [
    dependency('libadwaita-1'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-windows-terminal-services-tests', windows_terminal_services_test_exe)

windows_terminal_view_compile_test_exe = executable(
  'holder-linux-windows-terminal-view-compile-tests',
  [
    'src/services/windows/hidden_process.c',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/toolbox_nav.vala',
    'src/models/terminal_session.vala',
    'src/services/app_settings.vala',
    'src/services/powershell_transcript.vala',
    'src/services/windows/powershell_discovery.vala',
    'src/services/windows/terminal_session_store.vala',
    'src/services/windows/windows_terminal_launcher.vala',
    'src/controllers/terminal.vala',
    'src/views/toolbox/tool_adapter.vala',
    'src/views/toolbox/terminal_tool_view_windows.vala',
    'tests/windows_terminal_view_compile_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('libadwaita-1'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-windows-terminal-view-compile-tests', windows_terminal_view_compile_test_exe)

git_sync_service_test_exe = executable(
  'holder-linux-git-sync-service-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/git_sync_service.vala',
    'tests/git_sync_service_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
    dependency('libsoup-3.0'),
    dependency('libadwaita-1'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-git-sync-service-tests', git_sync_service_test_exe)

ai_catalog_controller_test_exe = executable(
  'holder-linux-ai-catalog-controller-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/controllers/ai_catalog.vala',
    'tests/ai_catalog_controller_test.vala',
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

test('holder-linux-ai-catalog-controller-tests', ai_catalog_controller_test_exe)

flowboard_controller_test_exe = executable(
  'holder-linux-flowboard-controller-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/controllers/flowboard.vala',
    'tests/flowboard_controller_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-flowboard-controller-tests', flowboard_controller_test_exe)

sidebar_data_renderer_test_exe = executable(
  'holder-linux-sidebar-data-renderer-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/controllers/sidebar_data_renderer.vala',
    'tests/sidebar_data_renderer_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gee-0.8'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-sidebar-data-renderer-tests', sidebar_data_renderer_test_exe)

local_info_controller_test_exe = executable(
  'holder-linux-local-info-controller-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/utils/text_utils.vala',
    'src/controllers/local_info.vala',
    'tests/local_info_controller_test.vala',
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

test('holder-linux-local-info-controller-tests', local_info_controller_test_exe)

local_info_flow_controller_test_exe = executable(
  'holder-linux-local-info-flow-controller-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/utils/text_utils.vala',
    'src/controllers/local_info.vala',
    'src/controllers/local_info_flow.vala',
    'tests/local_info_flow_controller_test.vala',
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

test('holder-linux-local-info-flow-controller-tests', local_info_flow_controller_test_exe)

local_info_presenter_test_exe = executable(
  'holder-linux-local-info-presenter-tests',
  [
    'src/controllers/local_info_presenter.vala',
    'tests/local_info_presenter_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-local-info-presenter-tests', local_info_presenter_test_exe)

local_info_view_adapter_test_exe = executable(
  'holder-linux-local-info-view-adapter-tests',
  [
    'src/controllers/local_info_presenter.vala',
    'src/views/adapters/local_info.vala',
    'tests/local_info_view_adapter_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-local-info-view-adapter-tests', local_info_view_adapter_test_exe)

api_client_test_exe = executable(
  'holder-linux-api-client-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/api_client_fakes.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/health.vala',
    'src/services/parsers/projects.vala',
    'src/services/parsers/cards.vala',
    'src/services/parsers/resources.vala',
    'src/services/parsers/trash.vala',
    'src/services/parsers/search.vala',
    'src/services/parsers/ai.vala',
    'src/services/parsers/git.vala',
    'src/services/api_client/core.vala',
    'src/services/api_client/transport.vala',
    'src/services/api_client/ai_stream.vala',
    'src/services/api_client/health.vala',
    'src/services/api_client/projects.vala',
    'src/services/api_client/cards.vala',
    'src/services/api_client/resources.vala',
    'src/services/api_client/trash.vala',
    'src/services/api_client/search.vala',
    'src/services/api_client/ai.vala',
    'src/services/api_client/git.vala',
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

api_client_ai_test_exe = executable(
  'holder-linux-api-client-ai-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/api_client_fakes.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/health.vala',
    'src/services/parsers/projects.vala',
    'src/services/parsers/cards.vala',
    'src/services/parsers/resources.vala',
    'src/services/parsers/trash.vala',
    'src/services/parsers/search.vala',
    'src/services/parsers/ai.vala',
    'src/services/parsers/git.vala',
    'src/services/api_client/core.vala',
    'src/services/api_client/transport.vala',
    'src/services/api_client/ai_stream.vala',
    'src/services/api_client/health.vala',
    'src/services/api_client/projects.vala',
    'src/services/api_client/cards.vala',
    'src/services/api_client/resources.vala',
    'src/services/api_client/trash.vala',
    'src/services/api_client/search.vala',
    'src/services/api_client/ai.vala',
    'src/services/api_client/git.vala',
    'tests/api_client_ai_test.vala',
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

test('holder-linux-api-client-ai-tests', api_client_ai_test_exe)

api_client_health_test_exe = executable(
  'holder-linux-api-client-health-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/api_client_fakes.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/health.vala',
    'src/services/parsers/projects.vala',
    'src/services/parsers/cards.vala',
    'src/services/parsers/resources.vala',
    'src/services/parsers/trash.vala',
    'src/services/parsers/search.vala',
    'src/services/parsers/ai.vala',
    'src/services/parsers/git.vala',
    'src/services/api_client/core.vala',
    'src/services/api_client/transport.vala',
    'src/services/api_client/ai_stream.vala',
    'src/services/api_client/health.vala',
    'src/services/api_client/projects.vala',
    'src/services/api_client/cards.vala',
    'src/services/api_client/resources.vala',
    'src/services/api_client/trash.vala',
    'src/services/api_client/search.vala',
    'src/services/api_client/ai.vala',
    'src/services/api_client/git.vala',
    'tests/api_client_health_test.vala',
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

test('holder-linux-api-client-health-tests', api_client_health_test_exe)

api_client_search_test_exe = executable(
  'holder-linux-api-client-search-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/api_client_fakes.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/health.vala',
    'src/services/parsers/projects.vala',
    'src/services/parsers/cards.vala',
    'src/services/parsers/resources.vala',
    'src/services/parsers/trash.vala',
    'src/services/parsers/search.vala',
    'src/services/parsers/ai.vala',
    'src/services/parsers/git.vala',
    'src/services/api_client/core.vala',
    'src/services/api_client/transport.vala',
    'src/services/api_client/ai_stream.vala',
    'src/services/api_client/health.vala',
    'src/services/api_client/projects.vala',
    'src/services/api_client/cards.vala',
    'src/services/api_client/resources.vala',
    'src/services/api_client/trash.vala',
    'src/services/api_client/search.vala',
    'src/services/api_client/ai.vala',
    'src/services/api_client/git.vala',
    'tests/api_client_search_test.vala',
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

test('holder-linux-api-client-search-tests', api_client_search_test_exe)

api_client_trash_test_exe = executable(
  'holder-linux-api-client-trash-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/api_client_fakes.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/health.vala',
    'src/services/parsers/projects.vala',
    'src/services/parsers/cards.vala',
    'src/services/parsers/resources.vala',
    'src/services/parsers/trash.vala',
    'src/services/parsers/search.vala',
    'src/services/parsers/ai.vala',
    'src/services/parsers/git.vala',
    'src/services/api_client/core.vala',
    'src/services/api_client/transport.vala',
    'src/services/api_client/ai_stream.vala',
    'src/services/api_client/health.vala',
    'src/services/api_client/projects.vala',
    'src/services/api_client/cards.vala',
    'src/services/api_client/resources.vala',
    'src/services/api_client/trash.vala',
    'src/services/api_client/search.vala',
    'src/services/api_client/ai.vala',
    'src/services/api_client/git.vala',
    'tests/api_client_trash_test.vala',
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

test('holder-linux-api-client-trash-tests', api_client_trash_test_exe)

api_client_resources_test_exe = executable(
  'holder-linux-api-client-resources-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/api_client_fakes.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/health.vala',
    'src/services/parsers/projects.vala',
    'src/services/parsers/cards.vala',
    'src/services/parsers/resources.vala',
    'src/services/parsers/trash.vala',
    'src/services/parsers/search.vala',
    'src/services/parsers/ai.vala',
    'src/services/parsers/git.vala',
    'src/services/api_client/core.vala',
    'src/services/api_client/transport.vala',
    'src/services/api_client/ai_stream.vala',
    'src/services/api_client/health.vala',
    'src/services/api_client/projects.vala',
    'src/services/api_client/cards.vala',
    'src/services/api_client/resources.vala',
    'src/services/api_client/trash.vala',
    'src/services/api_client/search.vala',
    'src/services/api_client/ai.vala',
    'src/services/api_client/git.vala',
    'tests/api_client_resources_test.vala',
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

test('holder-linux-api-client-resources-tests', api_client_resources_test_exe)

api_client_projects_test_exe = executable(
  'holder-linux-api-client-projects-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/api_client_fakes.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/health.vala',
    'src/services/parsers/projects.vala',
    'src/services/parsers/cards.vala',
    'src/services/parsers/resources.vala',
    'src/services/parsers/trash.vala',
    'src/services/parsers/search.vala',
    'src/services/parsers/ai.vala',
    'src/services/parsers/git.vala',
    'src/services/api_client/core.vala',
    'src/services/api_client/transport.vala',
    'src/services/api_client/ai_stream.vala',
    'src/services/api_client/health.vala',
    'src/services/api_client/projects.vala',
    'src/services/api_client/cards.vala',
    'src/services/api_client/resources.vala',
    'src/services/api_client/trash.vala',
    'src/services/api_client/search.vala',
    'src/services/api_client/ai.vala',
    'src/services/api_client/git.vala',
    'tests/api_client_projects_test.vala',
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

test('holder-linux-api-client-projects-tests', api_client_projects_test_exe)

api_client_cards_test_exe = executable(
  'holder-linux-api-client-cards-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/api_client_fakes.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/health.vala',
    'src/services/parsers/projects.vala',
    'src/services/parsers/cards.vala',
    'src/services/parsers/resources.vala',
    'src/services/parsers/trash.vala',
    'src/services/parsers/search.vala',
    'src/services/parsers/ai.vala',
    'src/services/parsers/git.vala',
    'src/services/api_client/core.vala',
    'src/services/api_client/transport.vala',
    'src/services/api_client/ai_stream.vala',
    'src/services/api_client/health.vala',
    'src/services/api_client/projects.vala',
    'src/services/api_client/cards.vala',
    'src/services/api_client/resources.vala',
    'src/services/api_client/trash.vala',
    'src/services/api_client/search.vala',
    'src/services/api_client/ai.vala',
    'src/services/api_client/git.vala',
    'tests/api_client_cards_test.vala',
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

test('holder-linux-api-client-cards-tests', api_client_cards_test_exe)

api_client_git_test_exe = executable(
  'holder-linux-api-client-git-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/api_client_fakes.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/health.vala',
    'src/services/parsers/projects.vala',
    'src/services/parsers/cards.vala',
    'src/services/parsers/resources.vala',
    'src/services/parsers/trash.vala',
    'src/services/parsers/search.vala',
    'src/services/parsers/ai.vala',
    'src/services/parsers/git.vala',
    'src/services/api_client/core.vala',
    'src/services/api_client/transport.vala',
    'src/services/api_client/ai_stream.vala',
    'src/services/api_client/health.vala',
    'src/services/api_client/projects.vala',
    'src/services/api_client/cards.vala',
    'src/services/api_client/resources.vala',
    'src/services/api_client/trash.vala',
    'src/services/api_client/search.vala',
    'src/services/api_client/ai.vala',
    'src/services/api_client/git.vala',
    'tests/api_client_git_test.vala',
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

test('holder-linux-api-client-git-tests', api_client_git_test_exe)

api_client_ai_stream_test_exe = executable(
  'holder-linux-api-client-ai-stream-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/api_client_fakes.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/health.vala',
    'src/services/parsers/projects.vala',
    'src/services/parsers/cards.vala',
    'src/services/parsers/resources.vala',
    'src/services/parsers/trash.vala',
    'src/services/parsers/search.vala',
    'src/services/parsers/ai.vala',
    'src/services/parsers/git.vala',
    'src/services/api_client/core.vala',
    'src/services/api_client/transport.vala',
    'src/services/api_client/ai_stream.vala',
    'src/services/api_client/health.vala',
    'src/services/api_client/projects.vala',
    'src/services/api_client/cards.vala',
    'src/services/api_client/resources.vala',
    'src/services/api_client/trash.vala',
    'src/services/api_client/search.vala',
    'src/services/api_client/ai.vala',
    'src/services/api_client/git.vala',
    'tests/api_client_ai_stream_test.vala',
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

test('holder-linux-api-client-ai-stream-tests', api_client_ai_stream_test_exe)

api_client_transport_test_exe = executable(
  'holder-linux-api-client-transport-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/api_client_fakes.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/health.vala',
    'src/services/parsers/projects.vala',
    'src/services/parsers/cards.vala',
    'src/services/parsers/resources.vala',
    'src/services/parsers/trash.vala',
    'src/services/parsers/search.vala',
    'src/services/parsers/ai.vala',
    'src/services/parsers/git.vala',
    'src/services/api_client/core.vala',
    'src/services/api_client/transport.vala',
    'src/services/api_client/ai_stream.vala',
    'src/services/api_client/health.vala',
    'src/services/api_client/projects.vala',
    'src/services/api_client/cards.vala',
    'src/services/api_client/resources.vala',
    'src/services/api_client/trash.vala',
    'src/services/api_client/search.vala',
    'src/services/api_client/ai.vala',
    'src/services/api_client/git.vala',
    'tests/api_client_transport_test.vala',
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

test('holder-linux-api-client-transport-tests', api_client_transport_test_exe)

api_client_core_test_exe = executable(
  'holder-linux-api-client-core-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/api_client_fakes.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/health.vala',
    'src/services/parsers/projects.vala',
    'src/services/parsers/cards.vala',
    'src/services/parsers/resources.vala',
    'src/services/parsers/trash.vala',
    'src/services/parsers/search.vala',
    'src/services/parsers/ai.vala',
    'src/services/parsers/git.vala',
    'src/services/api_client/core.vala',
    'src/services/api_client/transport.vala',
    'src/services/api_client/ai_stream.vala',
    'src/services/api_client/health.vala',
    'src/services/api_client/projects.vala',
    'src/services/api_client/cards.vala',
    'src/services/api_client/resources.vala',
    'src/services/api_client/trash.vala',
    'src/services/api_client/search.vala',
    'src/services/api_client/ai.vala',
    'src/services/api_client/git.vala',
    'tests/api_client_core_test.vala',
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

test('holder-linux-api-client-core-tests', api_client_core_test_exe)

discovery_test_exe = executable(
  'holder-linux-discovery-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
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
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
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

update_check_test_exe = executable(
  'holder-linux-update-check-tests',
  [
    holder_config,
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/app_settings.vala',
    'src/services/update_check.vala',
    'tests/update_check_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('libadwaita-1'),
    dependency('gee-0.8'),
    dependency('libsoup-3.0'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-update-check-tests', update_check_test_exe)

window_geometry_test_exe = executable(
  'holder-linux-window-geometry-tests',
  [
    'src/controllers/window_geometry.vala',
    'tests/window_geometry_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-window-geometry-tests', window_geometry_test_exe)

workspace_layout_test_exe = executable(
  'holder-linux-workspace-layout-tests',
  [
    'src/controllers/workspace_layout.vala',
    'tests/workspace_layout_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-workspace-layout-tests', workspace_layout_test_exe)

asset_preview_test_exe = executable(
  'holder-linux-asset-preview-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/asset_cache.vala',
    'src/controllers/asset_preview.vala',
    'tests/asset_preview_test.vala',
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

test('holder-linux-asset-preview-tests', asset_preview_test_exe)

flowboard_presenter_test_exe = executable(
  'holder-linux-flowboard-presenter-tests',
  [
    'src/models/flowboard.vala',
    'src/utils/text_utils.vala',
    'src/controllers/flowboard_presenter.vala',
    'tests/flowboard_presenter_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-flowboard-presenter-tests', flowboard_presenter_test_exe)

window_feedback_format_test_exe = executable(
  'holder-linux-window-feedback-format-tests',
  [
    'src/models/activity_details.vala',
    'src/controllers/window_feedback_format.vala',
    'tests/window_feedback_format_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gee-0.8'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-window-feedback-format-tests', window_feedback_format_test_exe)

app_transition_test_exe = executable(
  'holder-linux-app-transition-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/state/app_state.vala',
    'src/controllers/app_transition.vala',
    'tests/app_transition_test.vala',
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

test('holder-linux-app-transition-tests', app_transition_test_exe)

app_state_test_exe = executable(
  'holder-linux-app-state-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/state/app_state.vala',
    'tests/app_state_test.vala',
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

test('holder-linux-app-state-tests', app_state_test_exe)

editor_draft_state_test_exe = executable(
  'holder-linux-editor-draft-state-tests',
  [
    'src/models/card.vala',
    'src/state/editor_draft_state.vala',
    'tests/editor_draft_state_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-editor-draft-state-tests', editor_draft_state_test_exe)

selection_transition_test_exe = executable(
  'holder-linux-selection-transition-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/state/app_state.vala',
    'src/controllers/app_transition.vala',
    'src/controllers/selection_transition.vala',
    'tests/selection_transition_test.vala',
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

test('holder-linux-selection-transition-tests', selection_transition_test_exe)

selection_intent_test_exe = executable(
  'holder-linux-selection-intent-tests',
  [
    'src/controllers/selection_intent.vala',
    'tests/selection_intent_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-selection-intent-tests', selection_intent_test_exe)

selection_intent_orchestrator_test_exe = executable(
  'holder-linux-selection-intent-orchestrator-tests',
  [
    'src/controllers/selection_intent_orchestrator.vala',
    'tests/selection_intent_orchestrator_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-selection-intent-orchestrator-tests', selection_intent_orchestrator_test_exe)

activity_log_controller_test_exe = executable(
  'holder-linux-activity-log-controller-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/state/activity_log.vala',
    'src/controllers/activity_log.vala',
    'tests/activity_log_controller_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gee-0.8'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-activity-log-controller-tests', activity_log_controller_test_exe)

activity_reducer_test_exe = executable(
  'holder-linux-activity-reducer-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/state/activity_log.vala',
    'src/controllers/activity_reducer.vala',
    'tests/activity_reducer_test.vala',
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

test('holder-linux-activity-reducer-tests', activity_reducer_test_exe)

ai_panel_event_orchestrator_test_exe = executable(
  'holder-linux-ai-panel-event-orchestrator-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/controllers/ai_panel_event_orchestrator.vala',
    'tests/ai_panel_event_orchestrator_test.vala',
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

test('holder-linux-ai-panel-event-orchestrator-tests', ai_panel_event_orchestrator_test_exe)

card_append_test_exe = executable(
  'holder-linux-card-append-tests',
  [
    'src/controllers/card_append.vala',
    'tests/card_append_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-card-append-tests', card_append_test_exe)

explorer_selection_test_exe = executable(
  'holder-linux-explorer-selection-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/controllers/explorer_selection.vala',
    'tests/explorer_selection_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('gtk4'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-explorer-selection-tests', explorer_selection_test_exe)

find_replace_test_exe = executable(
  'holder-linux-find-replace-tests',
  [
    'src/controllers/find_replace.vala',
    'tests/find_replace_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-find-replace-tests', find_replace_test_exe)

search_selection_test_exe = executable(
  'holder-linux-search-selection-tests',
  [
    'src/controllers/search_selection.vala',
    'tests/search_selection_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gtk4'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-search-selection-tests', search_selection_test_exe)

selection_request_test_exe = executable(
  'holder-linux-selection-request-tests',
  [
    'src/controllers/selection_request.vala',
    'tests/selection_request_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gtk4'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-selection-request-tests', selection_request_test_exe)

share_controller_test_exe = executable(
  'holder-linux-share-controller-tests',
  [
    'src/services/uri_launcher.vala',
    'src/controllers/share.vala',
    'tests/share_controller_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-share-controller-tests', share_controller_test_exe)

tool_help_test_exe = executable(
  'holder-linux-tool-help-tests',
  [
    'src/controllers/tool_help.vala',
    'tests/tool_help_test.vala',
    help_resources,
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-tool-help-tests', tool_help_test_exe)

internal_link_test_exe = executable(
  'holder-linux-internal-link-tests',
  [
    'src/controllers/internal_link.vala',
    'tests/internal_link_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gee-0.8'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-internal-link-tests', internal_link_test_exe)

markdown_editing_test_exe = executable(
  'holder-linux-markdown-editing-tests',
  [
    'src/controllers/markdown_editing.vala',
    'tests/markdown_editing_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-markdown-editing-tests', markdown_editing_test_exe)

markdown_links_test_exe = executable(
  'holder-linux-markdown-links-tests',
  [
    'src/controllers/markdown_links.vala',
    'tests/markdown_links_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-markdown-links-tests', markdown_links_test_exe)

markdown_resource_images_test_exe = executable(
  'holder-linux-markdown-resource-images-tests',
  [
    'src/models/project.vala',
    'src/controllers/markdown_resource_images.vala',
    'src/controllers/editor_spellcheck.vala',
    'src/views/inline_resource_image_renderer.vala',
    'tests/markdown_resource_images_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('gtksourceview-5'),
    dependency('libspelling-1'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

markdown_resource_images_test_env = environment()
markdown_resource_images_test_env.set(
  'HOLDER_MARKDOWN_LANGUAGE_DIR',
  meson.project_source_root() / 'data' / 'gtksourceview-5' / 'language-specs',
)
test(
  'holder-linux-markdown-resource-images-tests',
  markdown_resource_images_test_exe,
  env: markdown_resource_images_test_env,
)

holder_markdown_language_test_exe = executable(
  'holder-linux-holder-markdown-language-tests',
  [
    'tests/holder_markdown_language_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('gtksourceview-5'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

holder_markdown_language_test_env = environment()
holder_markdown_language_test_env.set(
  'HOLDER_MARKDOWN_LANGUAGE_DIR',
  meson.project_source_root() / 'data' / 'gtksourceview-5' / 'language-specs',
)

test(
  'holder-linux-holder-markdown-language-tests',
  holder_markdown_language_test_exe,
  env: holder_markdown_language_test_env,
)

project_create_test_exe = executable(
  'holder-linux-project-create-tests',
  [
    'src/controllers/project_create.vala',
    'tests/project_create_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-project-create-tests', project_create_test_exe)

local_info_ui_test_exe = executable(
  'holder-linux-local-info-ui-tests',
  [
    'src/controllers/local_info_flow.vala',
    'src/controllers/local_info_ui.vala',
    'tests/local_info_ui_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-local-info-ui-tests', local_info_ui_test_exe)

window_feedback_orchestrator_test_exe = executable(
  'holder-linux-window-feedback-orchestrator-tests',
  [
    'src/controllers/window_feedback_orchestrator.vala',
    'tests/window_feedback_orchestrator_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-window-feedback-orchestrator-tests', window_feedback_orchestrator_test_exe)

window_event_binders_test_exe = executable(
  'holder-linux-window-event-binders-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/state/app_state.vala',
    'src/controllers/project_create.vala',
    'src/controllers/flowboard.vala',
    'src/controllers/app_transition.vala',
    'src/controllers/selection_transition.vala',
    'src/controllers/window_flowboard_event_binder.vala',
    'src/views/adapters/window_sidebar_events.vala',
    'src/views/adapters/window_selection_editor_events.vala',
    'src/views/adapters/window_lifecycle_events.vala',
    'src/views/adapters/window_workspace_events.vala',
    'src/views/adapters/window_state_events.vala',
    'tests/window_event_binders_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('gtksourceview-5'),
    dependency('libadwaita-1'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-window-event-binders-tests', window_event_binders_test_exe)

main_signal_binder_test_exe = executable(
  'holder-linux-main-signal-binder-tests',
  [
    'tests/support/ai_run_fakes.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/controllers/main_signal_binder.vala',
    'tests/main_signal_binder_test.vala',
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

test('holder-linux-main-signal-binder-tests', main_signal_binder_test_exe)

toolbox_event_orchestrator_test_exe = executable(
  'holder-linux-toolbox-event-orchestrator-tests',
  [
    'src/models/project.vala',
    'src/models/activity_details.vala',
    'src/controllers/toolbox_event_orchestrator.vala',
    'tests/toolbox_event_orchestrator_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gee-0.8'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-toolbox-event-orchestrator-tests', toolbox_event_orchestrator_test_exe)

window_action_binder_test_exe = executable(
  'holder-linux-window-action-binder-tests',
  [
    'src/controllers/window_action_binder.vala',
    'tests/window_action_binder_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-window-action-binder-tests', window_action_binder_test_exe)

recovery_ui_test_exe = executable(
  'holder-linux-recovery-ui-tests',
  [
    'src/controllers/recovery_ui.vala',
    'tests/recovery_ui_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-recovery-ui-tests', recovery_ui_test_exe)

flowboard_context_test_exe = executable(
  'holder-linux-flowboard-context-tests',
  [
    'src/controllers/flowboard_context.vala',
    'tests/flowboard_context_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-flowboard-context-tests', flowboard_context_test_exe)

sidebar_selection_renderer_test_exe = executable(
  'holder-linux-sidebar-selection-renderer-tests',
  [
    'src/controllers/sidebar_selection_renderer.vala',
    'tests/sidebar_selection_renderer_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gtk4'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-sidebar-selection-renderer-tests', sidebar_selection_renderer_test_exe)

toolbox_nav_models_test_exe = executable(
  'holder-linux-toolbox-nav-models-tests',
  [
    'src/models/toolbox_nav.vala',
    'tests/toolbox_nav_models_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-toolbox-nav-models-tests', toolbox_nav_models_test_exe)

models_test_exe = executable(
  'holder-linux-models-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'tests/models_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gee-0.8'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-models-tests', models_test_exe)

app_test_exe = executable(
  'holder-linux-app-tests',
  [
    'src/app.vala',
    'tests/app_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gtk4'),
    dependency('libadwaita-1'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-app-tests', app_test_exe)

print_service_test_exe = executable(
  'holder-linux-print-service-tests',
  [
    'tests/support/test_utils.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/print_service.vala',
    'tests/print_service_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-print-service-tests', print_service_test_exe)

trash_tool_view_test_exe = executable(
  'holder-linux-trash-tool-view-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/models/toolbox_nav.vala',
    'src/services/core_interfaces.vala',
    'src/controllers/trash.vala',
    'src/views/toolbox/tool_adapter.vala',
    'src/views/toolbox/trash_tool_view.vala',
    'tests/trash_tool_view_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('libadwaita-1'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-trash-tool-view-tests', trash_tool_view_test_exe)

resources_tool_view_test_exe = executable(
  'holder-linux-resources-tool-view-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/models/toolbox_nav.vala',
    'src/services/core_interfaces.vala',
    'src/services/resources_service.vala',
    'src/controllers/resources.vala',
    'src/views/toolbox/tool_adapter.vala',
    'src/views/toolbox/resources_tool_view.vala',
    'tests/resources_tool_view_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('libadwaita-1'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-resources-tool-view-tests', resources_tool_view_test_exe)

milestones_tool_view_test_exe = executable(
  'holder-linux-milestones-tool-view-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/models/toolbox_nav.vala',
    'src/services/core_interfaces.vala',
    'src/views/toolbox/tool_adapter.vala',
    'src/views/toolbox/milestones_tool_view.vala',
    'tests/milestones_tool_view_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('libadwaita-1'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-milestones-tool-view-tests', milestones_tool_view_test_exe)

git_sync_tool_view_test_exe = executable(
  'holder-linux-git-sync-tool-view-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/models/toolbox_nav.vala',
    'src/services/core_interfaces.vala',
    'src/services/app_settings.vala',
    'src/services/git_sync_service.vala',
    'src/controllers/git_sync_presenter.vala',
    'src/controllers/git_sync.vala',
    'src/views/toolbox/tool_adapter.vala',
    'src/views/toolbox/git_sync_tool_view.vala',
    'tests/git_sync_tool_view_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('libadwaita-1'),
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

test('holder-linux-git-sync-tool-view-tests', git_sync_tool_view_test_exe)

trash_controller_test_exe = executable(
  'holder-linux-trash-controller-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/controllers/trash.vala',
    'tests/trash_controller_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-trash-controller-tests', trash_controller_test_exe)

recovery_controller_test_exe = executable(
  'holder-linux-recovery-controller-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/ai_run_fakes.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/recovery_service.vala',
    'src/controllers/recovery.vala',
    'tests/recovery_controller_test.vala',
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

test('holder-linux-recovery-controller-tests', recovery_controller_test_exe)

recovery_service_test_exe = executable(
  'holder-linux-recovery-service-tests',
  [
    'src/services/recovery_service.vala',
    'tests/recovery_service_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-recovery-service-tests', recovery_service_test_exe)

parsers_health_test_exe = executable(
  'holder-linux-parsers-health-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/health.vala',
    'tests/parsers_health_test.vala',
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

test('holder-linux-parsers-health-tests', parsers_health_test_exe)

parsers_trash_test_exe = executable(
  'holder-linux-parsers-trash-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/trash.vala',
    'tests/parsers_trash_test.vala',
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

test('holder-linux-parsers-trash-tests', parsers_trash_test_exe)

parsers_search_test_exe = executable(
  'holder-linux-parsers-search-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/search.vala',
    'tests/parsers_search_test.vala',
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

test('holder-linux-parsers-search-tests', parsers_search_test_exe)

parsers_ai_test_exe = executable(
  'holder-linux-parsers-ai-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/ai.vala',
    'tests/parsers_ai_test.vala',
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

test('holder-linux-parsers-ai-tests', parsers_ai_test_exe)

parsers_cards_test_exe = executable(
  'holder-linux-parsers-cards-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/cards.vala',
    'tests/parsers_cards_test.vala',
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

test('holder-linux-parsers-cards-tests', parsers_cards_test_exe)

parsers_common_test_exe = executable(
  'holder-linux-parsers-common-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'tests/parsers_common_test.vala',
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

test('holder-linux-parsers-common-tests', parsers_common_test_exe)

parsers_git_test_exe = executable(
  'holder-linux-parsers-git-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/git.vala',
    'tests/parsers_git_test.vala',
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

test('holder-linux-parsers-git-tests', parsers_git_test_exe)

parsers_projects_test_exe = executable(
  'holder-linux-parsers-projects-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/projects.vala',
    'tests/parsers_projects_test.vala',
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

test('holder-linux-parsers-projects-tests', parsers_projects_test_exe)

parsers_resources_test_exe = executable(
  'holder-linux-parsers-resources-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/http_transport.vala',
    'src/services/parsers/common.vala',
    'src/services/parsers/resources.vala',
    'tests/parsers_resources_test.vala',
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

test('holder-linux-parsers-resources-tests', parsers_resources_test_exe)

toolbox_breadcrumb_controller_test_exe = executable(
  'holder-linux-toolbox-breadcrumb-controller-tests',
  [
    'src/controllers/toolbox_breadcrumb.vala',
    'tests/toolbox_breadcrumb_controller_test.vala',
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

test('holder-linux-toolbox-breadcrumb-controller-tests', toolbox_breadcrumb_controller_test_exe)

tool_shell_test_exe = executable(
  'holder-linux-tool-shell-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/models/toolbox_nav.vala',
    'src/views/components/navigation_breadcrumbs.vala',
    'src/views/components/tool_action_bar.vala',
    'src/views/toolbox/tool_shell.vala',
    'tests/tool_shell_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('libadwaita-1'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-tool-shell-tests', tool_shell_test_exe)

toolbox_small_views_test_exe = executable(
  'holder-linux-toolbox-small-views-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/models/toolbox_nav.vala',
    'src/state/activity_log.vala',
    'src/views/components/navigation_breadcrumbs.vala',
    'src/views/toolbox/tool_adapter.vala',
    'src/views/toolbox/debug_tool_view.vala',
    'src/views/toolbox/recovery_key_tool_view.vala',
    'src/views/toolbox/sharing_tool_view.vala',
    'tests/toolbox_small_views_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('libadwaita-1'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-toolbox-small-views-tests', toolbox_small_views_test_exe)

flowboard_pane_test_exe = executable(
  'holder-linux-flowboard-pane-tests',
  [
    'src/models/flowboard.vala',
    'src/utils/text_utils.vala',
    'src/controllers/flowboard_presenter.vala',
    'src/views/flowboard_pane.vala',
    'tests/flowboard_pane_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('libadwaita-1'),
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-flowboard-pane-tests', flowboard_pane_test_exe)

sidebar_pane_test_exe = executable(
  'holder-linux-sidebar-pane-tests',
  [
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/ai.vala',
    'src/utils/text_utils.vala',
    'src/views/sidebar.vala',
    'tests/sidebar_pane_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('libadwaita-1'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-sidebar-pane-tests', sidebar_pane_test_exe)

preferences_dialog_test_exe = executable(
  'holder-linux-preferences-dialog-tests',
  [
    'src/services/app_settings.vala',
    'src/services/editor_font_style.vala',
    'src/controllers/editor_spellcheck.vala',
    'src/views/preferences_dialog.vala',
    'tests/preferences_dialog_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('gtksourceview-5'),
    dependency('libadwaita-1'),
    dependency('libspelling-1'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-preferences-dialog-tests', preferences_dialog_test_exe)

ai_catalog_panel_view_test_exe = executable(
  'holder-linux-ai-catalog-panel-view-tests',
  [
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/controllers/ai_catalog.vala',
    'src/views/ai_panel/catalog.vala',
    'tests/ai_catalog_panel_view_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('libadwaita-1'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-ai-catalog-panel-view-tests', ai_catalog_panel_view_test_exe)

ai_config_panel_view_test_exe = executable(
  'holder-linux-ai-config-panel-view-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/uri_launcher.vala',
    'src/views/ai_panel/config.vala',
    'tests/ai_config_panel_view_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('libadwaita-1'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-ai-config-panel-view-tests', ai_config_panel_view_test_exe)

ai_panel_view_test_exe = executable(
  'holder-linux-ai-panel-view-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/services/core_interfaces.vala',
    'src/services/uri_launcher.vala',
    'src/views/ai_panel/config.vala',
    'src/views/ai_panel.vala',
    'tests/ai_panel_view_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('libadwaita-1'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-ai-panel-view-tests', ai_panel_view_test_exe)

tag_navigation_test_exe = executable(
  'holder-linux-tag-navigation-tests',
  [
    'src/models/card.vala',
    'src/controllers/tag_navigation.vala',
    'tests/tag_navigation_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-tag-navigation-tests', tag_navigation_test_exe)

tag_highlighting_test_exe = executable(
  'holder-linux-tag-highlighting-tests',
  [
    'src/models/card.vala',
    'src/controllers/tag_highlighting.vala',
    'tests/tag_highlighting_test.vala',
  ],
  dependencies: [
    dependency('gio-2.0'),
    dependency('gee-0.8'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-tag-highlighting-tests', tag_highlighting_test_exe)

tags_tool_view_test_exe = executable(
  'holder-linux-tags-tool-view-tests',
  [
    'tests/support/main_controller_fakes.vala',
    'src/services/editor_recovery_draft_service.vala',
    'src/models/server.vala',
    'src/models/project.vala',
    'src/models/card.vala',
    'src/models/flowboard.vala',
    'src/models/ai.vala',
    'src/models/git.vala',
    'src/models/recovery.vala',
    'src/models/card_context.vala',
    'src/models/activity_details.vala',
    'src/models/nudges.vala',
    'src/models/toolbox_nav.vala',
    'src/services/core_interfaces.vala',
    'src/views/toolbox/tool_adapter.vala',
    'src/views/toolbox/tags_tool_view.vala',
    'tests/tags_tool_view_test.vala',
  ],
  dependencies: [
    dependency('gtk4'),
    dependency('libadwaita-1'),
    dependency('gio-2.0'),
    dependency('gee-0.8'),
    dependency('json-glib-1.0'),
  ],
  vala_args: [
    '--target-glib=2.70',
  ],
  install: false,
)

test('holder-linux-tags-tool-view-tests', tags_tool_view_test_exe)
endif
