defmodule BotArmyLibraryLearning.Handlers.SessionHandler do
  @moduledoc """
  Handler for learning session lifecycle events.

  Processes:
  - learning.session.start - Start a new learning session
  - learning.session.answer - Record an answer in a session
  - learning.session.end - End a learning session
  """

  require Logger

  alias BotArmyLibraryLearning.SessionManager
  alias BotArmyLibraryLearning.NATS.Publisher

  @doc """
  Handle session start event.
  """
  def handle_start(message) when is_map(message) do
    %{tenant_id: tenant_id, user_id: user_id} = BotArmyLibraryCore.Tenant.extract_context(message)
    Logger.debug("SessionHandler: Processing session start event")

    payload = message["payload"] || %{}
    deck_id = payload["deck_id"]
    surface = payload["surface"] || "terminal"
    card_limit = payload["card_limit"]

    case SessionManager.start_session(deck_id, surface, card_limit) do
      {:ok, session} ->
        publish_session_started(message, session, tenant_id, user_id)

      {:error, reason} ->
        publish_error(message, reason, tenant_id, user_id)
    end
  end

  @doc """
  Handle session answer event.
  """
  def handle_answer(message) when is_map(message) do
    %{tenant_id: tenant_id, user_id: user_id} = BotArmyLibraryCore.Tenant.extract_context(message)
    Logger.debug("SessionHandler: Processing session answer event")

    payload = message["payload"] || %{}
    session_id = payload["session_id"]
    card_id = payload["card_id"]
    grade = payload["grade"]

    if session_id && card_id && grade do
      case SessionManager.record_answer(session_id, card_id, grade) do
        :ok ->
          publish_answer_recorded(message, session_id, card_id, grade, tenant_id, user_id)

        {:error, reason} ->
          publish_error(message, reason, tenant_id, user_id)
      end
    else
      publish_error(message, "Missing required fields", tenant_id, user_id)
    end
  end

  @doc """
  Handle session end event.
  """
  def handle_end(message) when is_map(message) do
    %{tenant_id: tenant_id, user_id: user_id} = BotArmyLibraryCore.Tenant.extract_context(message)
    Logger.debug("SessionHandler: Processing session end event")

    payload = message["payload"] || %{}
    session_id = payload["session_id"]

    case SessionManager.end_session(session_id) do
      :ok ->
        publish_session_complete(message, session_id, tenant_id, user_id)

      {:error, reason} ->
        publish_error(message, reason, tenant_id, user_id)
    end
  end

  # Private functions

  defp publish_session_started(message, session, tenant_id, user_id) do
    event = %{
      "event" => "learning.session.started",
      "event_id" => Elixir.UUID.uuid4(),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "source" => "bot_army_learning",
      "source_node" => node(),
      "triggered_by" => message["event_id"],
      "schema_version" => "1.0.0",
      "tenant_id" => tenant_id,
      "user_id" => user_id,
      "payload" => %{
        "session_id" => session.id,
        "deck_id" => session.deck_id,
        "surface" => session.surface
      }
    }

    Publisher.publish(event)
  end

  defp publish_answer_recorded(message, session_id, card_id, grade, tenant_id, user_id) do
    event = %{
      "event" => "learning.session.result",
      "event_id" => Elixir.UUID.uuid4(),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "source" => "bot_army_learning",
      "source_node" => node(),
      "triggered_by" => message["event_id"],
      "schema_version" => "1.0.0",
      "tenant_id" => tenant_id,
      "user_id" => user_id,
      "payload" => %{
        "session_id" => session_id,
        "card_id" => card_id,
        "grade" => grade
      }
    }

    Publisher.publish(event)
  end

  defp publish_session_complete(message, session_id, tenant_id, user_id) do
    event = %{
      "event" => "learning.session.complete",
      "event_id" => Elixir.UUID.uuid4(),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "source" => "bot_army_learning",
      "source_node" => node(),
      "triggered_by" => message["event_id"],
      "schema_version" => "1.0.0",
      "tenant_id" => tenant_id,
      "user_id" => user_id,
      "payload" => %{
        "session_id" => session_id
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
