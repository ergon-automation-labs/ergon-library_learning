defmodule BotArmyLibraryLearning.NATS.HealthResponder do
  @moduledoc """
  Health check responder for the Learning bot.

  Responds to health check requests on `bot_army.learning.health` subject
  with the current bot status and uptime.
  """

  use GenServer
  require Logger

  @version Mix.Project.config()[:version]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Learning health responder")
    {:ok, %{start_time: System.monotonic_time(:millisecond)}, {:continue, :setup}}
  end

  @impl true
  def handle_continue(:setup, state) do
    case GenServer.call(BotArmyLibraryRuntime.NATS.Connection, :get_connection, 5000) do
      {:ok, conn} ->
        setup_responder(conn, state)

      {:error, reason} ->
        Logger.warning(
          "Health responder: NATS connection not ready, retrying: #{inspect(reason)}"
        )

        Process.send_after(self(), :retry_setup, 5000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:retry_setup, state) do
    {:noreply, state, {:continue, :setup}}
  end

  @impl true
  def handle_info({:msg, msg}, state) do
    if msg.topic == "bot_army.learning.health" do
      handle_health_request(msg, state)
    else
      {:noreply, state}
    end
  end

  defp setup_responder(conn, state) do
    case Gnat.request(conn, "bot_army.learning.health", self()) do
      {:ok, _sub} ->
        Logger.info("Learning health responder listening on bot_army.learning.health")
        {:noreply, state}

      {:error, reason} ->
        Logger.warning("Failed to setup health responder: #{inspect(reason)}")
        Process.send_after(self(), :retry_setup, 5000)
        {:noreply, state}
    end
  end

  defp handle_health_request(msg, state) do
    uptime_ms = System.monotonic_time(:millisecond) - state.start_time

    response = %{
      "service" => "learning",
      "status" => "healthy",
      "version" => @version,
      "uptime_seconds" => div(uptime_ms, 1000),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case Jason.encode(response) do
      {:ok, json} ->
        if msg.reply_to do
          GenServer.call(BotArmyLibraryRuntime.NATS.Connection, :get_connection, 1000)
          |> case do
            {:ok, conn} -> Gnat.pub(conn, msg.reply_to, json)
            _ -> :ignore
          end
        end

      {:error, reason} ->
        Logger.warning("Failed to encode health response: #{inspect(reason)}")
    end

    {:noreply, state}
  end
end
