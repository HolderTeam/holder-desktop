from behave import given, then, when


@given("the Holder frontend is running")
def step_frontend_running(context):
    context.driver.launch()


@when("I create a new card")
def step_create_new_card(context):
    context.driver.create_card()


@then('I should see a card titled "{title_prefix}"')
def step_card_is_visible(context, title_prefix):
    assert context.driver.has_card_titled_prefix(title_prefix), (
        f"Expected a card with title prefix '{title_prefix}' to be visible"
    )
