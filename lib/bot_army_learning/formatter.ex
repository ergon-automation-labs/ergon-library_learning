defmodule BotArmyLibraryLearning.Formatter do
  @moduledoc """
  Message formatting for Learning Bot non-LLM notifications.

  Formats review reminders, deck updates, and learning milestone notifications
  with Learning Bot's curious guide voice.

  Reference: `/docs/north_star_docs/BOT_ARMY_PERSONALITY_NORTH_STAR.md`
  """

  require Logger
  alias BotArmyLibraryRuntime.Personality.Formatter

  @doc """
  Format learning notifications.

  Handles different notification types:
  - `:review_ready` — Cards ready for review
  - `:streak_milestone` — Learning streak milestone reached
  - `:deck_created` — New deck created
  - `:progress_update` — Progress in mastery
  - `:card_reviewed` — Card review processed
  - `:error` — Error notification
  """
  def format(:review_ready, %{"deck_name" => deck, "card_count" => count}) do
    Formatter.with_symbol(
      :learning_bot,
      "#{deck}: #{count} card#{if count == 1, do: "", else: "s"} ready for review."
    )
  end

  def format(:streak_milestone, %{"days" => days, "deck_name" => deck}) do
    Formatter.with_symbol(
      :learning_bot,
      "#{days} day streak on #{deck}. That's where the learning lives."
    )
  end

  def format(:deck_created, %{"deck_name" => name}) do
    Formatter.with_symbol(
      :learning_bot,
      "New deck: #{name}. Good. You're pushing into discomfort."
    )
  end

  def format(:progress_update, %{
        "deck_name" => deck,
        "mastered_count" => mastered,
        "total_count" => total
      }) do
    percentage = if total > 0, do: div(mastered * 100, total), else: 0

    Formatter.with_symbol(
      :learning_bot,
      "#{deck}: #{mastered}/#{total} mastered (#{percentage}%). Keep going."
    )
  end

  def format(:card_reviewed, %{"deck_name" => deck, "difficulty" => difficulty}) do
    msg =
      case difficulty do
        difficulty when difficulty <= 2 -> "That one's still hard. Keep wrestling with it."
        difficulty when difficulty <= 3 -> "Getting there. One more review cycle."
        _ -> "You've got it. Moving forward."
      end

    Formatter.with_symbol(:learning_bot, "#{deck}: #{msg}")
  end

  def format(:error, %{"message" => message}) do
    Formatter.with_symbol(:learning_bot, "Something went wrong: #{message}")
  end

  def format(_type, _data) do
    Logger.warning("Unknown Learning formatter type")
    Formatter.with_symbol(:learning_bot, "Something happened.")
  end
end
