from behave import step, then, when


@then("I should see the app shell")
def step_app_shell_visible(context):
    assert context.driver.has_app_shell(), (
        "Expected the main Holder shell to show sidebar, cards, editor, and toolbar"
    )


@then("I should see the search panel")
def step_search_panel_visible(context):
    assert context.driver.search_panel_is_visible(), (
        "Expected search panel to be visible"
    )


@when('I create project "{name}"')
def step_create_project(context, name):
    context.driver.create_project(name)


@then('I should see project "{name}"')
def step_project_visible(context, name):
    assert context.driver.has_project_named(name), (
        f"Expected project '{name}' to be visible"
    )


@when("I replace the editor text with")
def step_replace_editor_text(context):
    context.driver.replace_editor_text(context.text)


@then('I should see save state "{text}"')
def step_save_state_visible(context, text):
    assert context.driver.save_state_is_visible(text), (
        f"Expected save state '{text}' to be visible"
    )


@when('I search cards for "{query}"')
def step_search_cards(context, query):
    context.driver.search_cards(query)


@then('I should see search result "{text}"')
def step_search_result_visible(context, text):
    assert context.driver.has_search_result(text), (
        f"Expected search result '{text}' to be visible"
    )


@when('I open search result "{text}"')
def step_open_search_result(context, text):
    context.driver.open_search_result(text)


@when('I replace all "{find_text}" with "{replace_text}"')
def step_replace_all_in_editor(context, find_text, replace_text):
    context.driver.replace_all_in_editor(find_text, replace_text)


@then('the editor should contain "{text}"')
def step_editor_contains(context, text):
    assert context.driver.editor_text_contains(text), (
        f"Expected editor text to contain '{text}'"
    )


@then('the editor should not contain "{text}"')
def step_editor_excludes(context, text):
    assert context.driver.editor_text_excludes(text), (
        f"Expected editor text not to contain '{text}'"
    )


@when("I open find and replace")
def step_open_find_replace(context):
    context.driver.open_find_replace_panel()


@when("I toggle find and replace")
def step_toggle_find_replace(context):
    context.driver.toggle_find_replace_panel()


@then("I should see the find and replace panel")
def step_find_replace_visible(context):
    assert context.driver.find_replace_panel_is_visible(), (
        "Expected Find/Replace panel to be visible"
    )


@then("I should not see the find and replace panel")
def step_find_replace_hidden(context):
    assert context.driver.find_replace_panel_is_hidden(), (
        "Expected Find/Replace panel to be hidden"
    )


@when("I open preferences")
def step_open_preferences(context):
    context.driver.open_preferences()


@then("I should see preferences options")
def step_preferences_options_visible(context):
    assert context.driver.preferences_options_are_visible(), (
        "Expected Preferences dialog to show Appearance and Editor options"
    )


@when("I close preferences")
def step_close_preferences(context):
    context.driver.close_preferences()


@then("I should not see preferences")
def step_preferences_closed(context):
    assert context.driver.preferences_are_closed(), (
        "Expected Preferences dialog to be closed"
    )


@when("I toggle the AI panel")
@step("I toggle the AI panel")
def step_toggle_ai_panel(context):
    context.driver.toggle_ai_panel()


@then("I should see the AI panel")
def step_ai_panel_visible(context):
    assert context.driver.ai_panel_is_visible(), (
        "Expected AI panel to show Assistant/Config controls"
    )


@when("I open the toolbox panel")
def step_open_toolbox_panel(context):
    context.driver.open_toolbox_panel()


@then("I should see the toolbox shell")
def step_toolbox_shell_visible(context):
    assert context.driver.toolbox_shell_is_visible(), (
        "Expected ToolboxPane, ToolShell, breadcrumbs, and tool switcher to be visible"
    )


@then('I should see flowboard card "{title}"')
def step_flowboard_card_visible(context, title):
    assert context.driver.flowboard_has_card(title), (
        f"Expected flowboard to show card '{title}'"
    )


@when('I create a child card from flowboard card "{parent_title}"')
def step_create_flowboard_child_card(context, parent_title):
    context.driver.create_child_card_from_flowboard(parent_title)


@then('I should see Connections parent "{parent_title}"')
def step_connections_parent_visible(context, parent_title):
    assert context.driver.connections_show_parent_relation(parent_title), (
        f"Expected Connections to show parent relation '{parent_title}'"
    )


@when('I add a graph link from the selected card to "{target_title}"')
def step_add_graph_link(context, target_title):
    context.driver.add_graph_link_from_selected_card_to(target_title)


@then('I should see a Connections graph link to "{target_title}"')
def step_connections_graph_link_visible(context, target_title):
    assert context.driver.connections_graph_link_is_visible(target_title), (
        f"Expected Connections to show a graph link to '{target_title}'"
    )


@when('I switch to toolbox tool "{tool_name}"')
def step_switch_toolbox_tool(context, tool_name):
    context.driver.switch_toolbox_tool(tool_name)


@then('I should see toolbox content "{text}"')
def step_toolbox_content_visible(context, text):
    assert context.driver.can_see_text(text), (
        f"Expected toolbox content '{text}' to be visible"
    )


@when('I add URL resource "{label}" with URI "{uri}"')
def step_add_url_resource(context, label, uri):
    context.driver.add_url_resource(label, uri)


@when('I filter resources for "{query}"')
def step_filter_resources(context, query):
    context.driver.filter_resources(query)


@when('I delete resource "{label}"')
def step_delete_resource(context, label):
    context.driver.delete_resource(label)


@when('I move card "{title}" to Trash')
def step_move_card_to_trash(context, title):
    context.driver.move_card_to_trash(title)


@then('I should see trashed card "{title}"')
def step_trashed_card_visible(context, title):
    assert context.driver.trash_has_card(title), (
        f"Expected Trash to show card '{title}'"
    )


@when('I restore card "{title}" from Trash')
def step_restore_card_from_trash(context, title):
    context.driver.restore_card_from_trash(title)
