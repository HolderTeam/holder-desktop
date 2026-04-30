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
