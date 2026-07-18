defmodule BotArmyLibraryLearning.Handlers.CardHandler do
  @moduledoc """
  Handler for card and deck creation events.

  Processes:
  - learning.card.create - Create a new flashcard
  - learning.deck.create - Create a new deck
  """

  require Logger

  alias BotArmyLibraryLearning.CardStore
  alias BotArmyLibraryLearning.NATS.Publisher

  @doc """
  Handle card creation event.
  """
  def handle_create(message) when is_map(message) do
    %{tenant_id: tenant_id, user_id: user_id} = BotArmyLibraryCore.Tenant.extract_context(message)
    Logger.debug("CardHandler: Processing card create event")

    payload = message["payload"] || %{}

    case create_card(tenant_id, payload) do
      {:ok, card} ->
        publish_success(message, card, tenant_id, user_id)

      {:error, reason} ->
        publish_error(message, reason, tenant_id, user_id)
    end
  end

  @doc """
  Handle deck creation event.
  """
  def handle_deck_create(message) when is_map(message) do
    %{tenant_id: tenant_id, user_id: user_id} = BotArmyLibraryCore.Tenant.extract_context(message)
    Logger.debug("CardHandler: Processing deck create event")

    payload = message["payload"] || %{}

    case create_deck(tenant_id, payload) do
      {:ok, deck} ->
        publish_deck_success(message, deck, tenant_id, user_id)

      {:error, reason} ->
        publish_error(message, reason, tenant_id, user_id)
    end
  end

  # Private functions

  defp create_card(tenant_id, payload) do
    deck_id = payload["deck_id"]
    front = payload["front"]
    back = payload["back"]
    type = payload["type"] || "recall"
    tags = payload["tags"] || []

    if deck_id && front && back do
      CardStore.create_card(tenant_id, deck_id, %{
        front: front,
        back: back,
        type: type,
        tags: tags,
        due_at: Date.utc_today()
      })
    else
      {:error, "Missing required fields: deck_id, front, back"}
    end
  end

  defp create_deck(tenant_id, payload) do
    # Note: Deck creation deferred to Phase 2 when we have domain management
    name = payload["name"]
    _domain = payload["domain"]
    description = payload["description"]

    if name do
      # Stub implementation - Phase 2 will add proper domain/deck hierarchy
      {:ok, %{id: Elixir.UUID.uuid4(), name: name, description: description, tenant_id: tenant_id}}
    else
      {:error, "Missing required fields: name"}
    end
  end

  defp publish_success(message, card, tenant_id, user_id) do
    event = %{
      "event" => "learning.card.created",
      "event_id" => Elixir.UUID.uuid4(),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "source" => "bot_army_learning",
      "source_node" => node(),
      "triggered_by" => message["event_id"],
      "schema_version" => "1.0.0",
      "tenant_id" => tenant_id,
      "user_id" => user_id,
      "payload" => %{
        "card_id" => card.id,
        "deck_id" => card.deck_id
      }
    }

    Publisher.publish(event)
  end

  defp publish_deck_success(message, deck, tenant_id, user_id) do
    event = %{
      "event" => "learning.deck.created",
      "event_id" => Elixir.UUID.uuid4(),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "source" => "bot_army_learning",
      "source_node" => node(),
      "triggered_by" => message["event_id"],
      "schema_version" => "1.0.0",
      "tenant_id" => tenant_id,
      "user_id" => user_id,
      "payload" => %{
        "deck_id" => deck.id,
        "name" => deck.name
      }
    }

    Publisher.publish(event)
  end

  defp publish_error(message, reason, tenant_id, user_id) do
    event = %{
      "event" => "learning.error",
      "event_id" => Elixir.UUID.uuid4(),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "source" => "bot_army_learning",
      "source_node" => node(),
      "triggered_by" => message["event_id"],
      "schema_version" => "1.0.0",
      "tenant_id" => tenant_id,
      "user_id" => user_id,
      "payload" => %{
        "error" => inspect(reason)
      }
    }

    Publisher.publish(event)
  end
end
