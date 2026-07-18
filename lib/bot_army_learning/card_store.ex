defmodule BotArmyLibraryLearning.CardStore do
  @moduledoc """
  In-memory card store with Ecto persistence.

  Manages flashcard data, caches in memory, and persists to PostgreSQL.
  """

  use GenServer
  require Logger
  import Ecto.Query

  alias BotArmyLibraryLearning.Repo
  alias BotArmyLibraryLearning.Schemas.Card

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("CardStore starting...")
    {:ok, %{}}
  end

  @doc """
  List all cards in a deck for a tenant.
  """
  def list_cards_for_deck(tenant_id, deck_id) when is_binary(tenant_id) and is_binary(deck_id) do
    GenServer.call(__MODULE__, {:list_cards_for_deck, tenant_id, deck_id})
  end

  @doc """
  List cards due for review in a deck (limited to card_limit) for a tenant.
  """
  def list_due_cards(tenant_id, deck_id, limit \\ 20) when is_binary(tenant_id) and is_binary(deck_id) do
    GenServer.call(__MODULE__, {:list_due_cards, tenant_id, deck_id, limit})
  end

  @doc """
  Get a single card by ID for a tenant.
  """
  def get_card(tenant_id, card_id) when is_binary(tenant_id) and is_binary(card_id) do
    GenServer.call(__MODULE__, {:get_card, tenant_id, card_id})
  end

  @doc """
  Create a new card for a tenant.
  """
  def create_card(tenant_id, deck_id, attrs) when is_binary(tenant_id) and is_binary(deck_id) do
    GenServer.call(__MODULE__, {:create_card, tenant_id, deck_id, attrs})
  end

  @doc """
  Update an existing card for a tenant.
  """
  def update_card(tenant_id, card_id, attrs) when is_binary(tenant_id) and is_binary(card_id) do
    GenServer.call(__MODULE__, {:update_card, tenant_id, card_id, attrs})
  end

  @doc """
  Delete a card for a tenant.
  """
  def delete_card(tenant_id, card_id) when is_binary(tenant_id) and is_binary(card_id) do
    GenServer.call(__MODULE__, {:delete_card, tenant_id, card_id})
  end

  # GenServer callbacks

  @impl true
  def handle_call({:list_cards_for_deck, tenant_id, deck_id}, _from, state) do
    cards = Repo.all(from(c in Card, where: c.tenant_id == ^tenant_id and c.deck_id == ^deck_id))
    {:reply, cards, state}
  end

  @impl true
  def handle_call({:list_due_cards, tenant_id, deck_id, limit}, _from, state) do
    today = Date.utc_today()

    cards =
      Repo.all(
        from(c in Card,
          where: c.tenant_id == ^tenant_id and c.deck_id == ^deck_id and c.due_at <= ^today,
          limit: ^limit
        )
      )

    {:reply, cards, state}
  end

  @impl true
  def handle_call({:get_card, tenant_id, card_id}, _from, state) do
    card = Repo.get_by(Card, id: card_id, tenant_id: tenant_id)
    {:reply, card, state}
  end

  @impl true
  def handle_call({:create_card, tenant_id, deck_id, attrs}, _from, state) do
    result =
      Card.changeset(%Card{}, Map.merge(attrs, %{"tenant_id" => tenant_id, "deck_id" => deck_id}))
      |> Repo.insert()

    {:reply, result, state}
  end

  @impl true
  def handle_call({:update_card, tenant_id, card_id, attrs}, _from, state) do
    card = Repo.get_by(Card, id: card_id, tenant_id: tenant_id)

    if card do
      result = Card.changeset(card, attrs) |> Repo.update()
      {:reply, result, state}
    else
      {:reply, {:error, "Card not found"}, state}
    end
  end

  @impl true
  def handle_call({:delete_card, tenant_id, card_id}, _from, state) do
    card = Repo.get_by(Card, id: card_id, tenant_id: tenant_id)

    if card do
      case Repo.delete(card) do
        {:ok, _} -> {:reply, :ok, state}
        {:error, reason} -> {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, "Card not found"}, state}
    end
  end
end
