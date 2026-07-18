defmodule BotArmyLibraryLearning.Schemas.Session do
  @moduledoc """
  Learning session schema.

  Tracks an active study session for a particular deck.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "learning_sessions" do
    field :surface, :string, default: "terminal"
    field :card_limit, :integer
    field :cards_reviewed, :integer, default: 0
    field :status, :string, default: "active"

    belongs_to :deck, BotArmyLibraryLearning.Schemas.Deck
    has_many :reviews, BotArmyLibraryLearning.Schemas.Review

    field :tenant_id, :binary_id
    field :user_id, :binary_id
    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:surface, :card_limit, :cards_reviewed, :status, :deck_id, :tenant_id, :user_id])
    |> validate_required([:deck_id, :surface, :tenant_id])
  end
end
