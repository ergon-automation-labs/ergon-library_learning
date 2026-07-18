defmodule BotArmyLibraryLearning.FSRS do
  @moduledoc """
  Free Spaced Repetition Scheduler (FSRS-5) implementation.

  Pure functional FSRS module with zero side effects. Implements the core algorithm
  for spaced repetition scheduling.

  Grades: 0=again, 1=hard, 2=good, 3=easy
  """

  @doc """
  Calculate initial stability based on card grade.

  Grade 0 (again): 0.4 days
  Grade 1 (hard): 1.0 days
  Grade 2 (good): 2.5 days
  Grade 3 (easy): 7.0 days
  """
  def initial_stability(grade) when grade in [0, 1, 2, 3] do
    [0.4, 1.0, 2.5, 7.0]
    |> Enum.at(grade)
  end

  @doc """
  Calculate next difficulty based on current difficulty and grade.

  Formula: clamp(d + (3 - grade) * 0.1, 1.0, 10.0)
  """
  def next_difficulty(current_difficulty, grade) when grade in [0, 1, 2, 3] do
    new_difficulty = current_difficulty + (3 - grade) * 0.1
    clamp(new_difficulty, 1.0, 10.0)
  end

  @doc """
  Calculate next due date based on stability and retention target.

  Default retention is 90% (0.9).
  Formula: days = stability * ln(retention) / ln(0.9)
  """
  def next_due_at(stability, retention \\ 0.9) do
    days = stability * :math.log(retention) / :math.log(0.9)
    round(days)
  end

  @doc """
  Apply a review to a card and return updated card state.

  Returns {new_stability, new_difficulty, new_due_at_days, updated_card}
  """
  def apply_review(card, grade) when grade in [0, 1, 2, 3] do
    new_stability = initial_stability(grade)
    new_difficulty = next_difficulty(card.difficulty, grade)
    new_due_at_days = next_due_at(new_stability)

    {new_stability, new_difficulty, new_due_at_days}
  end

  defp clamp(value, min, max) do
    value
    |> max(min)
    |> min(max)
  end
end
