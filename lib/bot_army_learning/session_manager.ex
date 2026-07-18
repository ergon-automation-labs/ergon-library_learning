defmodule BotArmyLibraryLearning.SessionManager do
  @moduledoc """
  In-memory session manager for active learning sessions.

  Tracks active sessions and their card queues. On session end, writes to database.
  """

  use GenServer
  require Logger

  alias BotArmyLibraryLearning.Repo
  alias BotArmyLibraryLearning.Schemas.Session

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("SessionManager starting...")
    {:ok, %{sessions: %{}}}
  end

  @doc """
  Start a new learning session.
  """
  def start_session(deck_id, surface, card_limit) do
    GenServer.call(__MODULE__, {:start_session, deck_id, surface, card_limit})
  end

  @doc """
  Get the next card for a session.
  """
  def next_card(session_id) do
    GenServer.call(__MODULE__, {:next_card, session_id})
  end

  @doc """
  Record an answer for a card in a session.
  """
  def record_answer(session_id, card_id, grade) do
    GenServer.call(__MODULE__, {:record_answer, session_id, card_id, grade})
  end

  @doc """
  End a session and persist to database.
  """
  def end_session(session_id) do
    GenServer.call(__MODULE__, {:end_session, session_id})
  end

  # GenServer callbacks

  @impl true
  def handle_call({:start_session, deck_id, surface, card_limit}, _from, %{sessions: sessions}) do
    session_id = Elixir.UUID.uuid4()

    # Create session in database
    {:ok, db_session} =
      Session.changeset(%Session{}, %{
        id: session_id,
        deck_id: deck_id,
        surface: surface,
        card_limit: card_limit,
        status: "active"
      })
      |> Repo.insert()

    new_sessions =
      Map.put(sessions, session_id, %{
        session_id: session_id,
        deck_id: deck_id,
        surface: surface,
        card_limit: card_limit,
        card_queue: [],
        current_card_id: nil,
        cards_reviewed: 0,
        started_at: DateTime.utc_now()
      })

    {:reply, {:ok, db_session}, %{sessions: new_sessions}}
  end

  @impl true
  def handle_call({:next_card, session_id}, _from, %{sessions: sessions} = state) do
    case Map.get(sessions, session_id) do
      nil ->
        {:reply, {:error, "Session not found"}, state}

      _session ->
        # TODO: load cards from CardStore based on deck_id
        {:reply, {:ok, nil}, state}
    end
  end

  @impl true
  def handle_call({:record_answer, session_id, _card_id, _grade}, _from, %{sessions: sessions} = state) do
    case Map.get(sessions, session_id) do
      nil ->
        {:reply, {:error, "Session not found"}, state}

      session ->
        updated_session = %{session | cards_reviewed: session.cards_reviewed + 1}
        new_sessions = Map.put(sessions, session_id, updated_session)
        {:reply, :ok, %{sessions: new_sessions}}
    end
  end

  @impl true
  def handle_call({:end_session, session_id}, _from, %{sessions: sessions}) do
    case Map.get(sessions, session_id) do
      nil ->
        {:reply, {:error, "Session not found"}, %{sessions: sessions}}

      _session ->
        # Update session in database
        session_record = Repo.get(Session, session_id)

        if session_record do
          {:ok, _updated} =
            Session.changeset(session_record, %{status: "completed"})
            |> Repo.update()
        end

        new_sessions = Map.delete(sessions, session_id)
        {:reply, :ok, %{sessions: new_sessions}}
    end
  end
end
