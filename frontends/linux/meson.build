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
  'src/models/toolbox_nav_models.vala',
  'src/state/app_state.vala',
  'src/state/editor_draft_state.vala',
  'src/state/activity_log.vala',
  'src/services/core_interfaces.vala',
  'src/services/app_settings.vala',
  'src/services/print_service.vala',
  'src/services/git_sync_service.vala',
  'src/services/resources_service.vala',
  'src/utils/text_utils.vala',
  'src/views/sidebar.vala',
  'src/views/ai_panel.vala',
  'src/views/preferences_dialog.vala',
  'src/views/search.vala',
  'src/views/flowboard_pane.vala',
  'src/views/components/navigation_breadcrumbs.vala',
  'src/views/components/tool_action_bar.vala',
  'src/views/adapters/local_info.vala',
  'src/views/adapters/window_actions.vala',
  'src/views/adapters/card_action_dialog.vala',
  'src/views/adapters/project_create_dialog.vala',
  'src/views/adapters/recovery_dialog.vala',
  'src/views/toolbox.vala',
  'src/views/toolbox/tool_shell.vala',
  'src/views/toolbox/tool_adapter.vala',
  'src/views/toolbox/connections_tool_view.vala',
  'src/views/ai_panel/config.vala',
  'src/views/toolbox/debug_tool_view.vala',
  'src/views/toolbox/flowboard_tool_view.vala',
  'src/views/toolbox/git_sync_tool_view.vala',
  'src/views/toolbox/recovery_key_tool_view.vala',
  'src/views/toolbox/resources_tool_view.vala',
  'src/views/toolbox/sharing_tool_view.vala',
  'src/views/toolbox/terminal_tool_view.vala',
  'src/views/toolbox/trash_tool_view.vala',
  'src/services/ui_adapters.vala',
  'src/views/workspace_pane.vala',
  'src/controllers/main.vala',
  'src/controllers/projects.vala',
  'src/controllers/cards.vala',
  'src/controllers/search.vala',
  'src/controllers/project_create.vala',
  'src/controllers/share.vala',
  'src/controllers/card_append.vala',
  'src/controllers/search_selection.vala',
  'src/controllers/activity_log.vala',
  'src/controllers/activity_reducer.vala',
  'src/controllers/selection_request.vala',
  'src/controllers/selection_intent.vala',
  'src/controllers/selection_intent_orchestrator.vala',
  'src/controllers/explorer_selection.vala',
  'src/controllers/sidebar_data_renderer.vala',
  'src/controllers/sidebar_selection_renderer.vala',
  'src/controllers/selection.vala',
  'src/controllers/selection_transition.vala',
  'src/controllers/toolbox_breadcrumb.vala',
  'src/controllers/toolbox_event_orchestrator.vala',
  'src/controllers/window_feedback_orchestrator.vala',
  'src/controllers/window_action_binder.vala',
  'src/controllers/window_view_event_binder.vala',
  'src/controllers/window_interaction_event_binder.vala',
  'src/controllers/ai_threads.vala',
  'src/controllers/ai_run.vala',
  'src/controllers/ai_panel_event_orchestrator.vala',
  'src/controllers/print_ui.vala',
  'src/controllers/git_sync.vala',
  'src/controllers/resources.vala',
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

executable(
  'holder-desktop',
  [sources, help_resources],
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
    'src/models/models.vala',
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

main_controller_test_exe = executable(
  'holder-linux-main-controller-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'tests/support/main_controller_harness.vala',
    'src/models/models.vala',
    'src/services/core_interfaces.vala',
    'src/state/editor_draft_state.vala',
    'src/utils/text_utils.vala',
    'src/controllers/main.vala',
    'src/controllers/projects.vala',
    'src/controllers/cards.vala',
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

git_sync_controller_test_exe = executable(
  'holder-linux-git-sync-controller-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'src/models/models.vala',
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

resources_controller_test_exe = executable(
  'holder-linux-resources-controller-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
    'src/models/toolbox_nav_models.vala',
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

git_sync_service_test_exe = executable(
  'holder-linux-git-sync-service-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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

app_transition_test_exe = executable(
  'holder-linux-app-transition-tests',
  [
    'src/models/models.vala',
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

selection_transition_test_exe = executable(
  'holder-linux-selection-transition-tests',
  [
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
    'src/models/toolbox_nav_models.vala',
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
    '--define=TRASH_TOOL_VIEW_TEST',
  ],
  install: false,
)

test('holder-linux-trash-tool-view-tests', trash_tool_view_test_exe)

trash_controller_test_exe = executable(
  'holder-linux-trash-controller-tests',
  [
    'tests/support/test_utils.vala',
    'tests/support/main_controller_fakes.vala',
    'src/models/models.vala',
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
    'src/models/models.vala',
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

parsers_health_test_exe = executable(
  'holder-linux-parsers-health-tests',
  [
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
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
    'src/models/models.vala',
    'src/models/toolbox_nav_models.vala',
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
