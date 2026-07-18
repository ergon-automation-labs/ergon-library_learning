defmodule BotArmyLibraryLearning.ThresholdAdapter do
  @moduledoc """
  Adapts decision thresholds based on historical outcome accuracy.

  Given a category's accuracy from `OutcomeTracker`, computes an
  adjusted threshold multiplier. High accuracy tightens thresholds
  (fewer false positives), low accuracy loosens them (more conservative).

  ## Usage

      BotArmyLibraryLearning.ThresholdAdapter.adjustment("intent.nudge")
      # => 0.9  (tighten by 10% if accuracy is high)
  """

  @doc """
  Compute a threshold adjustment factor for a category.

  Returns a float multiplier:
    - accuracy > 0.9 → 0.9 (tighten)
    - accuracy < 0.5 → 1.2 (loosen)
    - otherwise → 1.0 (no change)

  Pass `opts` to override defaults:
    - `:tighten_threshold` — accuracy threshold for tightening (default 0.9)
    - `:loosen_threshold` — accuracy threshold for loosening (default 0.5)
    - `:tighten_factor` — multiplier when tightening (default 0.9)
    - `:loosen_factor` — multiplier when loosening (default 1.2)
  """
  def adjustment(category, opts \\ []) do
    stats = BotArmyLibraryLearning.OutcomeTracker.stats(category)
    adjustment_for_accuracy(stats.accuracy, opts)
  end

  @doc """
  Apply an adjustment to a base threshold value.

  ## Example

      iex> BotArmyLibraryLearning.ThresholdAdapter.apply_adjustment(0.7, 0.9)
      0.63
  """
  def apply_adjustment(base_threshold, adjustment_factor) do
    base_threshold * adjustment_factor
  end

  # ── Private ─────────────────────────────────────────────────

  defp adjustment_for_accuracy(accuracy, opts) do
    tighten = Keyword.get(opts, :tighten_threshold, 0.9)
    loosen = Keyword.get(opts, :loosen_threshold, 0.5)
    tighten_factor = Keyword.get(opts, :tighten_factor, 0.9)
    loosen_factor = Keyword.get(opts, :loosen_factor, 1.2)

    cond do
      accuracy > tighten -> tighten_factor
      accuracy < loosen -> loosen_factor
      true -> 1.0
    end
  end
end
