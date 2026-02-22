@linux
Feature: Toolbox Panel
  As a Holder user
  I want to open and close the toolbox panel
  So that I can access debug and AI tools when needed

  Scenario: Toggle toolbox panel visibility
    Given the Holder frontend is running
    When I toggle the toolbox panel
    Then I should see the toolbox panel
    And I toggle the toolbox panel
    Then I should not see the toolbox panel
