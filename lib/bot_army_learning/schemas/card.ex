defmodule BotArmyLibraryLearning.Schemas.Card do
  @moduledoc """
  Learning card schema.

  A single flashcard with front/back content and FSRS scheduling fields.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "learning_cards" do
    field :front, :string
    field :back, :string
    field :type, :string, default: "recall"
    field :tags, {:array, :string}, default: []

    # FSRS fields
    field :stability, :float, default: 2.5
    field :difficulty, :float, default: 5.0
    field :due_at, :date

    belongs_to :deck, BotArmyLibraryLearning.Schemas.Deck
    has_many :reviews, BotArmyLibraryLearning.Schemas.Review
    has_many :snoozes, BotArmyLibraryLearning.Schemas.Snooze

    field :tenant_id, :binary_id
    field :user_id, :binary_id
    timestamps()
  end

  def changeset(card, attrs) do
    card
    |> cast(attrs, [:front, :back, :type, :tags, :stability, :difficulty, :due_at, :deck_id, :tenant_id, :user_id])
    |> validate_required([:front, :back, :deck_id, :tenant_id])
  end
end
