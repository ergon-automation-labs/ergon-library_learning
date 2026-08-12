defmodule BotArmyLibraryLearning.Application do
  @moduledoc """
  BotArmyLearning application supervisor.

  Manages Learning bot services:
  - NATS message consumer
  - Session manager for active learning sessions
  - Card storage (in-memory + Ecto persistence)
  """

  use Application

  @env Mix.env()

  @impl true
  def start(_type, _args) do
    children =
      []
      |> maybe_add_repo()
      |> maybe_add_card_store()
      |> maybe_add_session_manager()
      |> maybe_add_pulse_publisher()
      |> maybe_add_consumer()
      |> maybe_add_health_responder()

    opts = [strategy: :one_for_one, name: BotArmyLibraryLearning.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_add_repo(children) do
    # Only add Repo when explicitly enabled (running as standalone bot, not as a library)
    if @env == :test or not enabled?(),
      do: children,
      else: [BotArmyLibraryLearning.Repo | children]
  end

  defp maybe_add_card_store(children) do
    if @env == :test or not enabled?(),
      do: children,
      else: [{BotArmyLibraryLearning.CardStore, []} | children]
  end

  defp maybe_add_session_manager(children) do
    if @env == :test or not enabled?(),
      do: children,
      else: [{BotArmyLibraryLearning.SessionManager, []} | children]
  end

  defp maybe_add_pulse_publisher(children) do
    if @env == :test or not enabled?(),
      do: children,
      else: [{BotArmyLibraryLearning.PulsePublisher, []} | children]
  end

  defp maybe_add_consumer(children) do
    if @env == :test or not enabled?(),
      do: children,
      else: [{BotArmyLibraryLearning.NATS.Consumer, []} | children]
  end

  defp maybe_add_health_responder(children) do
    if @env == :test or not enabled?(),
      do: children,
      else: [{BotArmyLibraryLearning.NATS.HealthResponder, []} | children]
  end

  defp enabled?() do
    # Only start infrastructure if explicitly running as the learning bot
    Application.get_env(:bot_army_library_learning, :enabled, false)
  end
end
