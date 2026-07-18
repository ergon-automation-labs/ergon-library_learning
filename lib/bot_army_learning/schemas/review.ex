defmodule BotArmyLibraryLearning.Schemas.Review do
  @moduledoc """
  Card review record schema.

  Records each time a user reviews a card in a session.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "learning_reviews" do
    field :grade, :integer
    field :review_duration_ms, :integer

    belongs_to :card, BotArmyLibraryLearning.Schemas.Card
    belongs_to :session, BotArmyLibraryLearning.Schemas.Session

    field :tenant_id, :binary_id
    field :user_id, :binary_id
    timestamps()
  end

  def changeset(review, attrs) do
    review
    |> cast(attrs, [:grade, :review_duration_ms, :card_id, :session_id, :tenant_id, :user_id])
    |> validate_required([:grade, :card_id, :session_id, :tenant_id])
    |> validate_inclusion(:grade, [0, 1, 2, 3])
  end
end
