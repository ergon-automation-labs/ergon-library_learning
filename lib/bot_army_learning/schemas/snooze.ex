defmodule BotArmyLibraryLearning.Schemas.Snooze do
  @moduledoc """
  Card snooze record schema.

  Temporarily suspends a card from being shown in sessions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "learning_snoozes" do
    field :snoozed_until, :utc_datetime
    field :reason, :string

    belongs_to :card, BotArmyLibraryLearning.Schemas.Card

    field :tenant_id, :binary_id
    field :user_id, :binary_id
    timestamps()
  end

  def changeset(snooze, attrs) do
    snooze
    |> cast(attrs, [:snoozed_until, :reason, :card_id, :tenant_id, :user_id])
    |> validate_required([:snoozed_until, :card_id, :tenant_id])
  end
end
