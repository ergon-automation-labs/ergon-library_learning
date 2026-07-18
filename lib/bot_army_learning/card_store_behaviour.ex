defmodule BotArmyLibraryLearning.CardStoreBehaviour do
  @moduledoc """
  Behavior for card storage backends.

  Allows for flexible implementation: Ecto persistence, in-memory mocking, etc.
  """

  @callback list_cards_for_deck(tenant_id :: String.t(), deck_id :: String.t()) :: [map()]
  @callback list_due_cards(tenant_id :: String.t(), deck_id :: String.t(), limit :: integer()) :: [map()]
  @callback get_card(tenant_id :: String.t(), card_id :: String.t()) :: map() | nil
  @callback create_card(tenant_id :: String.t(), deck_id :: String.t(), attrs :: map()) :: {:ok, map()} | {:error, String.t()}
  @callback update_card(tenant_id :: String.t(), card_id :: String.t(), attrs :: map()) :: {:ok, map()} | {:error, String.t()}
  @callback delete_card(tenant_id :: String.t(), card_id :: String.t()) :: :ok | {:error, String.t()}
end
