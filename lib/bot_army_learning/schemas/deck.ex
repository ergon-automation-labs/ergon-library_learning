defmodule BotArmyLibraryLearning.Schemas.Deck do
  @moduledoc """
  Learning deck schema.

  A deck contains a collection of flashcards for learning a specific topic.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "learning_decks" do
    field :name, :string
    field :description, :string
    field :card_count, :integer, default: 0

    belongs_to :domain, BotArmyLibraryLearning.Schemas.Domain
    has_many :cards, BotArmyLibraryLearning.Schemas.Card
    has_many :sessions, BotArmyLibraryLearning.Schemas.Session

    field :tenant_id, :binary_id
    field :user_id, :binary_id
    timestamps()
  end

  def changeset(deck, attrs) do
    deck
    |> cast(attrs, [:name, :description, :domain_id, :card_count, :tenant_id, :user_id])
    |> validate_required([:name, :domain_id, :tenant_id])
  end
end
