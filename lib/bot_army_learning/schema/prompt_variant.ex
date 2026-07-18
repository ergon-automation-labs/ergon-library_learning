defmodule BotArmyLibraryLearning.Schema.PromptVariant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "learning_prompt_variants" do
    field(:task_type, :string)
    field(:prompt_hash, :string)
    field(:prompt_text, :string)
    field(:total_score, :float)
    field(:uses, :integer)
    field(:last_updated_at, :utc_datetime)

    timestamps(updated_at: false, inserted_at: :created_at)
  end

  def changeset(variant, attrs) do
    variant
    |> cast(attrs, [
      :task_type,
      :prompt_hash,
      :prompt_text,
      :total_score,
      :uses,
      :last_updated_at
    ])
    |> validate_required([
      :task_type,
      :prompt_hash,
      :prompt_text,
      :total_score,
      :uses,
      :last_updated_at
    ])
    |> unique_constraint(:task_type_prompt_hash,
      name: :learning_prompt_variants_task_type_prompt_hash_index
    )
  end
end
