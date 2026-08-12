defmodule BotArmyLibraryLearning.NATS.Consumer do
  @moduledoc """
  NATS message consumer for the Learning bot.

  Subscribes to NATS subjects matching Learning message patterns:
  - `learning.session.*` - Session control events
  - `learning.card.*` - Card creation/management events
  - `learning.deck.*` - Deck creation events

  Messages are decoded using BotArmyLibraryCore.NATS.Decoder and routed to
  appropriate handlers based on the event type.
  """

  use GenServer
  require Logger

  @reconnect_delay_ms 5000
  @version Mix.Project.config()[:version]
  @registry_heartbeat_ms 20_000

  @subjects [
    %{subject: "learning.session.start", type: :subscribe, description: "Start learning session"},
    %{
      subject: "learning.session.answer",
      type: :subscribe,
      description: "Answer learning question"
    },
    %{subject: "learning.session.end", type: :subscribe, description: "End learning session"},
    %{subject: "learning.card.create", type: :subscribe, description: "Create learning card"},
    %{subject: "learning.deck.create", type: :subscribe, description: "Create learning deck"},
    %{
      subject: "gossip.poll.broadcast",
      type: :subscribe,
      description: "Army general poll broadcasts"
    },
    %{
      subject: "bot_army.learning.health",
      type: :request_reply,
      description: "Learning bot health check"
    }
  ]

  # API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Callbacks

  @impl true
  def init(opts) do
    Logger.info("Starting Learning NATS consumer")

    state = %{
      subscriptions: [],
      reconnect_attempt: 0,
      opts: opts
    }

    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    case GenServer.call(BotArmyLibraryRuntime.NATS.Connection, :get_connection, 5000) do
      {:ok, conn} ->
        BotArmyLibraryRuntime.NATS.Connection.subscribe_to_status()
        subscribe_to_topics(conn, state)

      {:error, _reason} ->
        handle_connection_unavailable(state)
    end
  end

  defp subscribe_to_topics(conn, state) do
    Logger.info("Connected to NATS, subscribing to Learning topics")

    subjects = [
      "learning.session.start",
      "learning.session.answer",
      "learning.session.end",
      "learning.card.create",
      "learning.deck.create",
      "gossip.poll.broadcast"
    ]

    subs =
      Enum.reduce_while(subjects, [], fn subject, acc ->
        case Gnat.sub(conn, self(), subject) do
          {:ok, sub} ->
            Logger.info("Learning consumer subscribed to #{subject}")
            {:cont, [sub | acc]}

          {:error, reason} ->
            Logger.error("Failed to subscribe to #{subject}: #{inspect(reason)}")
            {:halt, acc}
        end
      end)

    case subs do
      subs when length(subs) == length(subjects) ->
        BotArmyLibraryRuntime.Registry.register("learning", @subjects, @version)
        Process.send_after(self(), :registry_heartbeat, @registry_heartbeat_ms)
        {:noreply, %{state | subscriptions: subs}}

      _ ->
        Logger.error("Failed to subscribe to all Learning topics")
        Process.send_after(self(), :reconnect, @reconnect_delay_ms)
        {:noreply, state}
    end
  end

  defp handle_connection_unavailable(state) do
    Logger.warning("NATS connection not ready, will retry")
    Process.send_after(self(), :connect_retry, @reconnect_delay_ms)
    {:noreply, state}
  end

  @impl true
  def handle_info(:connect_retry, state) do
    {:noreply, state, {:continue, :connect}}
  end

  @impl true
  def handle_info({:msg, msg}, state) do
    BotArmyLibraryRuntime.Tracing.with_consumer_span(msg.topic, Map.get(msg, :headers, []), fn ->
      Logger.debug("Received NATS message on subject: #{msg.topic}")

      if msg.topic == "gossip.poll.broadcast" do
        case Jason.decode(msg.body) do
          {:ok, decoded} -> BotArmyLibraryLearning.GossipPollVoter.handle_poll_broadcast(decoded)
          {:error, reason} -> Logger.warning("Failed to decode gossip poll: #{inspect(reason)}")
        end
      else
        case BotArmyLibraryCore.NATS.Decoder.decode(msg.body) do
          {:ok, decoded_message} ->
            route_message(decoded_message)

          {:error, reason} ->
            Logger.warning("Failed to decode message from #{msg.topic}: #{inspect(reason)}")
        end
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(:reconnect, state) do
    Logger.info("Attempting to reconnect to NATS")
    {:noreply, state, {:continue, :connect}}
  end

  @impl true
  def handle_info({:nats, :disconnected}, state) do
    Logger.warning("Disconnected from NATS, will reconnect")
    Process.send_after(self(), :reconnect, @reconnect_delay_ms)
    {:noreply, %{state | subscriptions: []}}
  end

  @impl true
  def handle_info({:nats, :connected}, state) do
    Logger.info("Reconnected to NATS, re-subscribing")
    {:noreply, state, {:continue, :connect}}
  end

  @impl true
  def handle_info(:registry_heartbeat, state) do
    if state.subscriptions != [] do
      BotArmyLibraryRuntime.Registry.register("learning", @subjects, @version)
      BotArmyLibraryLearning.GossipPollVoter.maybe_vote_on_heartbeat()
      Process.send_after(self(), :registry_heartbeat, @registry_heartbeat_ms)
    end

    {:noreply, state}
  end

  # Private functions

  @doc """
  Route decoded message to appropriate handler based on event type.
  """
  def route_message(message) do
    event = message["event"]

    case event do
      "learning.session.start" ->
        BotArmyLibraryLearning.Handlers.SessionHandler.handle_start(message)

      "learning.session.answer" ->
        BotArmyLibraryLearning.Handlers.SessionHandler.handle_answer(message)

      "learning.session.end" ->
        BotArmyLibraryLearning.Handlers.SessionHandler.handle_end(message)

      "learning.card.create" ->
        BotArmyLibraryLearning.Handlers.CardHandler.handle_create(message)

      "learning.deck.create" ->
        BotArmyLibraryLearning.Handlers.CardHandler.handle_deck_create(message)

      _ ->
        Logger.debug("Unknown Learning event type: #{event}")
    end
  end
end
