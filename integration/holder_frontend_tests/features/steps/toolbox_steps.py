from behave import step, then, when


@when("I toggle the toolbox panel")
@step("I toggle the toolbox panel")
def step_toggle_toolbox_panel(context):
    context.driver.toggle_toolbox_panel()


@then("I should see the toolbox panel")
def step_toolbox_panel_visible(context):
    assert context.driver.toolbox_panel_is_visible(), (
        "Expected toolbox panel to be visible"
    )


@then("I should not see the toolbox panel")
def step_toolbox_panel_hidden(context):
    assert context.driver.toolbox_panel_is_hidden(), (
        "Expected toolbox panel to be hidden"
    )
