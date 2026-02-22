from behave import then, when


@when("I toggle the toolbox panel")
def step_toggle_toolbox_panel(context):
    context.driver.toggle_toolbox_panel()


@then("I should see the toolbox panel")
def step_toolbox_panel_visible(context):
    assert context.driver.toolbox_panel_is_visible(), (
        "Expected toolbox panel to be visible"
    )
