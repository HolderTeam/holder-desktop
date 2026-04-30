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
