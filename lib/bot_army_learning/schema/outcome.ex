defmodule BotArmyLibraryLearning.Schema.Outcome do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "learning_outcomes" do
    field(:item_id, :string)
    field(:category, :string)
    field(:decision, :string)
    field(:actual_result, :string)
    field(:was_correct, :boolean)
    field(:recorded_at, :utc_datetime)

    timestamps(updated_at: false)
  end

  def changeset(outcome, attrs) do
    outcome
    |> cast(attrs, [:item_id, :category, :decision, :actual_result, :was_correct, :recorded_at])
    |> validate_required([
      :item_id,
      :category,
      :decision,
      :actual_result,
      :was_correct,
      :recorded_at
    ])
  end
end
