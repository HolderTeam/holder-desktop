@linux
Feature: Core app run book
  As a Holder user
  I want the core app flows to work in one session
  So that the integration suite follows real usage rather than restarting per check

  Scenario: Create a card from the toolbar
    Given the Holder frontend is running
    Then I should see the app shell
    When I create a new card
    Then I should see a card titled "Untitled"

  Scenario: Edit a card and find it from search
    Given the Holder frontend is running
    When I replace the editor text with
      """
      # Runbook Search Card

      This card includes runbook-search-token.
      """
    Then I should see save state "Saved"
    When I search cards for "runbook-search-token"
    Then I should see search result "Runbook Search Card"

  Scenario: Use find and replace in the editor
    Given the Holder frontend is running
    When I replace all "runbook-search-token" with "runbook-replaced-token"
    Then I should see save state "Saved"
    When I search cards for "runbook-replaced-token"
    Then I should see search result "Runbook Search Card"

  Scenario: Use search and AI side panels
    Given the Holder frontend is running
    Then I should see the search panel
    When I toggle the AI panel
    Then I should see the AI panel
    And I toggle the AI panel

  Scenario: Toggle toolbox panel visibility
    Given the Holder frontend is running
    When I toggle the toolbox panel
    Then I should see the toolbox panel
    And I toggle the toolbox panel
    Then I should not see the toolbox panel

  Scenario: Walk toolbox views
    Given the Holder frontend is running
    When I open the toolbox panel
    Then I should see toolbox content "Flowboard"
    When I switch to toolbox tool "Connections"
    Then I should see toolbox content "Add graph connection"
    When I switch to toolbox tool "Resources"
    Then I should see toolbox content "No resources in this project."
    When I switch to toolbox tool "Sharing"
    Then I should see toolbox content "Send card as email"
    When I switch to toolbox tool "Terminals"
    Then I should see toolbox content "New Terminal"
    When I switch to toolbox tool "Git Sync"
    Then I should see toolbox content "Guided (I'm new to this)"
    When I switch to toolbox tool "Recovery Key"
    Then I should see toolbox content "Email Recovery Key"
    When I switch to toolbox tool "Trash"
    Then I should see toolbox content "No deleted items in this project."
    When I switch to toolbox tool "Debug"
    Then I should see toolbox content "Clear"

  Scenario: Add, filter, and delete a project resource
    Given the Holder frontend is running
    When I open the toolbox panel
    And I add URL resource "Runbook Resource" with URI "https://holder.team/runbook"
    Then I should see toolbox content "Runbook Resource"
    When I filter resources for "Runbook"
    Then I should see toolbox content "Runbook Resource"
    When I delete resource "Runbook Resource"
    Then I should see toolbox content "No resources in this project."
