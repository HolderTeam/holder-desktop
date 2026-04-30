@linux
Feature: Core app run book
  As a Holder user
  I want the core app flows to work in one session
  So that the integration suite follows real usage rather than restarting per check

  Scenario: Create a card from the toolbar
    Given the Holder frontend is running
    When I create a new card
    Then I should see a card titled "Untitled"

  Scenario: Toggle toolbox panel visibility
    Given the Holder frontend is running
    When I toggle the toolbox panel
    Then I should see the toolbox panel
    And I toggle the toolbox panel
    Then I should not see the toolbox panel
