defmodule Mix.Tasks.Learning.Card.New do
  @moduledoc """
  Create a new flashcard in a deck.

  Usage:
    mix learning.card.new --deck-id <UUID> --front "What is 2+2?" --back "4"
    mix learning.card.new --deck-id <UUID> --front "ἀγαθός" --back "good, noble" --type recall --tags "greek,vocab"
  """

  use Mix.Task

  alias BotArmyLibraryLearning.Repo
  alias BotArmyLibraryLearning.Schemas.{Deck, Card}

  @shortdoc "Create a new flashcard"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start", [])

    {opts, _} =
      OptionParser.parse!(args,
        strict: [
          deck_id: :string,
          front: :string,
          back: :string,
          type: :string,
          tags: :string
        ]
      )

    deck_id = opts[:deck_id]
    front = opts[:front]
    back = opts[:back]
    type = opts[:type] || "recall"
    tags = parse_tags(opts[:tags])

    case validate_inputs(deck_id, front, back) do
      {:ok, _} ->
        create_card(deck_id, front, back, type, tags)

      {:error, reason} ->
        Mix.shell().error(reason)
        exit({:shutdown, 1})
    end
  end

  defp validate_inputs(deck_id, front, back)
       when is_nil(deck_id) or is_nil(front) or is_nil(back) do
    {:error, "Error: --deck-id, --front, and --back are required"}
  end

  defp validate_inputs(deck_id, _front, _back) do
    case Repo.get(Deck, deck_id) do
      nil -> {:error, "Error: Deck not found (ID: #{deck_id})"}
      deck -> {:ok, deck}
    end
  end

  defp create_card(deck_id, front, back, type, tags) do
    changeset =
      Card.changeset(%Card{}, %{
        deck_id: deck_id,
        front: front,
        back: back,
        type: type,
        tags: tags,
        due_at: Date.utc_today(),
        stability: 2.5,
        difficulty: 5.0
      })

    case Repo.insert(changeset) do
      {:ok, card} ->
        Mix.shell().info("")
        Mix.shell().info("✓ Card created successfully")
        Mix.shell().info("")
        Mix.shell().info("  ID:       #{card.id}")
        Mix.shell().info("  Front:    #{card.front}")
        Mix.shell().info("  Back:     #{card.back}")
        Mix.shell().info("  Type:     #{card.type}")
        Mix.shell().info("  Due:      #{card.due_at}")
        Mix.shell().info("  Tags:     #{Enum.join(card.tags, ", ")}")
        Mix.shell().info("")

      {:error, changeset} ->
        Mix.shell().error("Error creating card:")
        Enum.each(changeset.errors, fn {field, {msg, _}} ->
          Mix.shell().error("  #{field}: #{msg}")
        end)

        exit({:shutdown, 1})
    end
  end

  defp parse_tags(nil), do: []
  defp parse_tags(""), do: []

  defp parse_tags(tags_string) do
    tags_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
