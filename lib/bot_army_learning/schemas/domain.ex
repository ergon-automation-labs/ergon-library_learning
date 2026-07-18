defmodule BotArmyLibraryLearning.Schemas.Domain do
  @moduledoc """
  Learning domain schema.

  A domain groups related decks (e.g., 'greek_language', 'mathematics').
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "learning_domains" do
    field :name, :string
    field :description, :string

    has_many :decks, BotArmyLibraryLearning.Schemas.Deck

    field :tenant_id, :binary_id
    field :user_id, :binary_id
    timestamps()
  end

  def changeset(domain, attrs) do
    domain
    |> cast(attrs, [:name, :description, :tenant_id, :user_id])
    |> validate_required([:name, :tenant_id])
  end
end
