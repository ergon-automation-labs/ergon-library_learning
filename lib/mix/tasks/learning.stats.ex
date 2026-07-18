defmodule Mix.Tasks.Learning.Stats do
  @moduledoc """
  Show learning statistics.

  Displays:
  - Total decks and cards
  - Due cards by deck (due today or overdue)
  - Card type distribution
  - FSRS statistics

  Usage:
    mix learning.stats
    mix learning.stats --deck-id <UUID>
  """

  use Mix.Task
  import Ecto.Query

  alias BotArmyLibraryLearning.Repo
  alias BotArmyLibraryLearning.Schemas.{Domain, Deck, Card}

  @shortdoc "Show learning statistics"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start", [])

    {opts, _} = OptionParser.parse!(args, strict: [deck_id: :string])

    case opts[:deck_id] do
      nil -> show_global_stats()
      deck_id -> show_deck_stats(deck_id)
    end
  end

  defp show_global_stats do
    Mix.shell().info("")
    Mix.shell().info("=" <> String.duplicate("=", 50))
    Mix.shell().info("Learning Bot Statistics")
    Mix.shell().info("=" <> String.duplicate("=", 50))
    Mix.shell().info("")

    # Count domains, decks, cards
    domain_count = Repo.aggregate(Domain, :count, :id)
    deck_count = Repo.aggregate(Deck, :count, :id)
    card_count = Repo.aggregate(Card, :count, :id)

    Mix.shell().info("Overview:")
    Mix.shell().info("  Domains: #{domain_count}")
    Mix.shell().info("  Decks:   #{deck_count}")
    Mix.shell().info("  Cards:   #{card_count}")
    Mix.shell().info("")

    # Due cards
    today = Date.utc_today()

    due_count =
      Repo.aggregate(
        from(c in Card, where: c.due_at <= ^today),
        :count,
        :id
      )

    Mix.shell().info("Review Status:")
    Mix.shell().info("  Due today or overdue: #{due_count}")
    Mix.shell().info("")

    # Card types
    show_card_type_distribution()

    # FSRS statistics
    show_fsrs_stats()

    Mix.shell().info("")
    Mix.shell().info("=" <> String.duplicate("=", 50))
  end

  defp show_deck_stats(deck_id) do
    case Repo.get(Deck, deck_id) do
      nil ->
        Mix.shell().error("Deck not found (ID: #{deck_id})")
        exit({:shutdown, 1})

      deck ->
        show_deck_details(deck)
    end
  end

  defp show_deck_details(deck) do
    Mix.shell().info("")
    Mix.shell().info("=" <> String.duplicate("=", 50))
    Mix.shell().info("Deck: #{deck.name}")
    Mix.shell().info("=" <> String.duplicate("=", 50))
    Mix.shell().info("")

    deck = Repo.preload(deck, :domain)

    Mix.shell().info("Deck Information:")
    Mix.shell().info("  ID:       #{deck.id}")
    Mix.shell().info("  Domain:   #{deck.domain.name}")
    Mix.shell().info("  Created:  #{deck.inserted_at |> NaiveDateTime.to_date()}")

    if deck.description do
      Mix.shell().info("  Desc:     #{deck.description}")
    end

    Mix.shell().info("")

    # Card count
    card_count = Repo.aggregate(from(c in Card, where: c.deck_id == ^deck.id), :count, :id)

    today = Date.utc_today()

    due_count =
      Repo.aggregate(
        from(c in Card, where: c.deck_id == ^deck.id and c.due_at <= ^today),
        :count,
        :id
      )

    Mix.shell().info("Cards:")
    Mix.shell().info("  Total:             #{card_count}")
    Mix.shell().info("  Due today/overdue: #{due_count}")
    Mix.shell().info("")

    # Card type distribution for this deck
    type_dist =
      Repo.all(
        from(c in Card,
          where: c.deck_id == ^deck.id,
          group_by: c.type,
          select: {c.type, count(c.id)}
        )
      )

    if Enum.any?(type_dist) do
      Mix.shell().info("Card Types:")

      Enum.each(type_dist, fn {type, count} ->
        Mix.shell().info("  #{type}: #{count}")
      end)

      Mix.shell().info("")
    end

    # FSRS stats for this deck
    show_deck_fsrs_stats(deck.id)

    Mix.shell().info("")
    Mix.shell().info("=" <> String.duplicate("=", 50))
  end

  defp show_card_type_distribution do
    type_dist =
      Repo.all(
        from(c in Card,
          group_by: c.type,
          select: {c.type, count(c.id)}
        )
      )

    if Enum.any?(type_dist) do
      Mix.shell().info("Card Types:")

      Enum.each(type_dist, fn {type, count} ->
        Mix.shell().info("  #{type}: #{count}")
      end)

      Mix.shell().info("")
    end
  end

  defp show_fsrs_stats do
    cards = Repo.all(Card)

    if Enum.any?(cards) do
      stability_values = Enum.map(cards, & &1.stability)
      difficulty_values = Enum.map(cards, & &1.difficulty)

      avg_stability = Enum.sum(stability_values) / length(stability_values)
      avg_difficulty = Enum.sum(difficulty_values) / length(difficulty_values)

      Mix.shell().info("FSRS Statistics:")
      Mix.shell().info("  Avg Stability:   #{Float.round(avg_stability, 2)} days")
      Mix.shell().info("  Avg Difficulty:  #{Float.round(avg_difficulty, 2)}")
      Mix.shell().info("")
    end
  end

  defp show_deck_fsrs_stats(deck_id) do
    cards = Repo.all(from(c in Card, where: c.deck_id == ^deck_id))

    if Enum.any?(cards) do
      stability_values = Enum.map(cards, & &1.stability)
      difficulty_values = Enum.map(cards, & &1.difficulty)

      avg_stability = Enum.sum(stability_values) / length(stability_values)
      avg_difficulty = Enum.sum(difficulty_values) / length(difficulty_values)

      Mix.shell().info("FSRS Statistics:")
      Mix.shell().info("  Avg Stability:   #{Float.round(avg_stability, 2)} days")
      Mix.shell().info("  Avg Difficulty:  #{Float.round(avg_difficulty, 2)}")
      Mix.shell().info("")
    end
  end
end
