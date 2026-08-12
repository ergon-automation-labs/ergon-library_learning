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
    case Gnat.sub(conn, self(), "bot_army.learning.health") do
      {:ok, _sub} ->
        Logger.info("Learning health responder listening on bot_army.learning.health")
        {:noreply, state}

      {:error, reason} ->
        Logger.warning("Failed to setup health responder: #{inspect(reason)}")
        Process.send_after(self(), :retry_setup, 5000)
        {:noreply, state}
    end
  end

  @doc """
  Builds the health response body for a process started at `start_time`
  (a `System.monotonic_time(:millisecond)` reading).
  """
  def health_payload(start_time) do
    uptime_ms = System.monotonic_time(:millisecond) - start_time

    %{
      "service" => "learning",
      "status" => "healthy",
      "version" => @version,
      "uptime_seconds" => div(uptime_ms, 1000),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp handle_health_request(msg, state) do
    case Jason.encode(health_payload(state.start_time)) do
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
