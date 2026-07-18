defmodule BotArmyLibraryLearning.PulsePublisher do
  @moduledoc """
  Publishes health pulses for the Learning bot.

  Tracks learning engagement metrics:
  - Active learners and sessions
  - Cards generated and reviewed
  - Spaced repetition system health
  """

  use GenServer
  require Logger

  @health_interval_ms 30 * 1000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Start the publish loop
    schedule_publish()
    Process.send_after(self(), :publish_health, 2_000)
    {:ok, %{active_sessions: 0, cards_reviewed: 0, cards_generated: 0}}
  end

  def record_session_active(learner_id) do
    GenServer.cast(__MODULE__, {:session_active, learner_id})
  end

  def record_card_review(difficulty) do
    GenServer.cast(__MODULE__, {:card_review, difficulty})
  end

  def record_card_generated(domain) do
    GenServer.cast(__MODULE__, {:card_generated, domain})
  end

  @impl true
  def handle_cast({:session_active, _learner_id}, state) do
    {:noreply, Map.update(state, :active_sessions, 1, &(&1 + 1))}
  end

  @impl true
  def handle_cast({:card_review, _difficulty}, state) do
    {:noreply, Map.update(state, :cards_reviewed, 1, &(&1 + 1))}
  end

  @impl true
  def handle_cast({:card_generated, _domain}, state) do
    {:noreply, Map.update(state, :cards_generated, 1, &(&1 + 1))}
  end

  @impl true
  def handle_info(:publish, state) do
    publish_pulse(state)
    schedule_publish()
    {:noreply, %{active_sessions: 0, cards_reviewed: 0, cards_generated: 0}}
  end

  @impl true
  def handle_info(:publish_health, state) do
    publish_system_health(state)
    Process.send_after(self(), :publish_health, @health_interval_ms)
    {:noreply, state}
  end

  defp schedule_publish do
    Process.send_after(self(), :publish, 5 * 60 * 1000)
  end

  defp publish_system_health(metrics) do
    health_signal =
      if metrics.active_sessions > 0 or metrics.cards_reviewed > 0 do
        "nominal"
      else
        "degraded"
      end

    BotArmyLibraryRuntime.SynapseHealth.publish(
      source: "bot_army_learning",
      service: "learning",
      health_signal: health_signal
    )
  end

  defp publish_pulse(metrics) do
    try do
      health_signal =
        if metrics.active_sessions > 0 or metrics.cards_reviewed > 0 do
          "nominal"
        else
          "degraded"
        end

      payload = %{
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "service" => "learning",
        "health_signal" => health_signal,
        "metrics" => %{
          "active_sessions" => metrics.active_sessions,
          "cards_reviewed" => metrics.cards_reviewed,
          "cards_generated" => metrics.cards_generated
        }
      }

      subject = "bot.learning.pulse"

      case BotArmyLibraryRuntime.NATS.Publisher.publish(subject, payload) do
        {:ok, _} ->
          Logger.info("[PulsePublisher] Published learning pulse to #{subject}")

        {:error, reason} ->
          Logger.warning("[PulsePublisher] Failed to publish pulse: #{inspect(reason)}")
      end
    rescue
      e ->
        Logger.error("[PulsePublisher] Error publishing pulse: #{inspect(e)}")
    end
  end
end
