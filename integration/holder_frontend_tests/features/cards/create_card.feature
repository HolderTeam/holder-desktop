@linux
Feature: Cards
  As a Holder user
  I want to create cards from the frontend
  So that I can capture cards quickly

  Scenario: Create a card from the toolbar
    Given the Holder frontend is running
    When I create a new card
    Then I should see a card titled "Untitled"
