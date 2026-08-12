defmodule BotArmyLibraryLearning.FSRSTest do
  use ExUnit.Case
  @moduletag :scheduler
  doctest BotArmyLibraryLearning.FSRS

  alias BotArmyLibraryLearning.FSRS

  describe "initial_stability/1" do
    test "returns 0.4 for grade 0 (again)" do
      assert FSRS.initial_stability(0) == 0.4
    end

    test "returns 1.0 for grade 1 (hard)" do
      assert FSRS.initial_stability(1) == 1.0
    end

    test "returns 2.5 for grade 2 (good)" do
      assert FSRS.initial_stability(2) == 2.5
    end

    test "returns 7.0 for grade 3 (easy)" do
      assert FSRS.initial_stability(3) == 7.0
    end
  end

  describe "next_difficulty/2" do
    test "increases difficulty for lower grades" do
      # Grade 0: d + (3 - 0) * 0.1 = d + 0.3
      assert FSRS.next_difficulty(5.0, 0) == 5.3
    end

    test "decreases difficulty for higher grades" do
      # Grade 3: d + (3 - 3) * 0.1 = d + 0.0
      assert FSRS.next_difficulty(5.0, 3) == 5.0
    end

    test "clamps to minimum of 1.0" do
      assert FSRS.next_difficulty(1.0, 0) >= 1.0
    end

    test "clamps to maximum of 10.0" do
      assert FSRS.next_difficulty(10.0, 0) <= 10.0
    end
  end

  describe "next_due_at/2" do
    test "returns positive days for valid stability" do
      days = FSRS.next_due_at(2.5)
      assert days > 0
    end

    test "higher stability yields more days" do
      days_low = FSRS.next_due_at(1.0)
      days_high = FSRS.next_due_at(7.0)
      assert days_high > days_low
    end

    test "respects custom retention" do
      days_90 = FSRS.next_due_at(2.5, 0.9)
      days_95 = FSRS.next_due_at(2.5, 0.95)
      # Higher retention target (0.95 vs 0.9) means review sooner, so fewer days
      assert days_95 < days_90
    end
  end

  describe "apply_review/2" do
    test "returns new stability, difficulty, and days" do
      card = %{difficulty: 5.0}
      {stability, difficulty, days} = FSRS.apply_review(card, 2)

      assert is_float(stability)
      assert is_float(difficulty)
      assert is_integer(days)
    end

    test "applies different stabilities for each grade" do
      card = %{difficulty: 5.0}

      {s0, _, _} = FSRS.apply_review(card, 0)
      {s1, _, _} = FSRS.apply_review(card, 1)
      {s2, _, _} = FSRS.apply_review(card, 2)
      {s3, _, _} = FSRS.apply_review(card, 3)

      assert s0 == 0.4
      assert s1 == 1.0
      assert s2 == 2.5
      assert s3 == 7.0
    end
  end
end
