defmodule BotArmyLibraryLearningTest do
  use ExUnit.Case
  @moduletag :core

  alias BotArmyLibraryLearning.{OutcomeTracker, ThresholdAdapter, PromptOptimizer}

  setup do
    start_supervised!(OutcomeTracker)
    start_supervised!(PromptOptimizer)
    OutcomeTracker.reset()
    PromptOptimizer.reset()
    :ok
  end

  describe "OutcomeTracker" do
    test "records and computes accuracy" do
      OutcomeTracker.record("a", "factory", "approved", "pass")
      OutcomeTracker.record("b", "factory", "approved", "fail")
      OutcomeTracker.record("c", "factory", "rejected", "fail")

      stats = OutcomeTracker.stats("factory")
      assert stats.total == 3
      assert stats.correct == 2
      assert stats.accuracy == 2.0 / 3.0
    end

    test "classifies outcomes correctly" do
      OutcomeTracker.record("a", "intent", "act", "success")
      OutcomeTracker.record("b", "intent", "act", "failure")
      OutcomeTracker.record("c", "intent", "defer", "failure")
      OutcomeTracker.record("d", "intent", "defer", "success")

      stats = OutcomeTracker.stats("intent")
      assert stats.total == 4
      assert stats.correct == 2
    end

    test "uses custom correctness_fn when provided" do
      custom_fn = fn decision, result ->
        # Custom domain: github PRs
        # "approved" + "merged" = correct (not "pass")
        # "requested_changes" + "fixed" = correct
        case {decision, result} do
          {"approved", "merged"} -> true
          {"approved", "rejected"} -> false
          {"requested_changes", "fixed"} -> true
          {"requested_changes", "abandoned"} -> true
          _ -> false
        end
      end

      {:ok, pid} =
        OutcomeTracker.start_link(
          name: :custom_tracker,
          correctness_fn: custom_fn
        )

      OutcomeTracker.record("pr1", "github.pr_review", "approved", "merged", :custom_tracker)
      OutcomeTracker.record("pr2", "github.pr_review", "approved", "rejected", :custom_tracker)

      OutcomeTracker.record(
        "pr3",
        "github.pr_review",
        "requested_changes",
        "fixed",
        :custom_tracker
      )

      stats = OutcomeTracker.stats("github.pr_review", :custom_tracker)
      assert stats.total == 3
      assert stats.correct == 2
      assert stats.accuracy == 2.0 / 3.0

      GenServer.stop(pid)
    end
  end

  describe "ThresholdAdapter" do
    test "returns tighten factor when accuracy is high" do
      Enum.each(1..10, fn i ->
        OutcomeTracker.record("p#{i}", "intent", "act", "success")
      end)

      assert ThresholdAdapter.adjustment("intent") == 0.9
    end

    test "returns loosen factor when accuracy is low" do
      Enum.each(1..10, fn i ->
        OutcomeTracker.record("p#{i}", "intent", "act", "failure")
      end)

      assert ThresholdAdapter.adjustment("intent") == 1.2
    end

    test "returns 1.0 for moderate accuracy" do
      Enum.each(1..5, fn i ->
        OutcomeTracker.record("p#{i}", "intent", "act", "success")
      end)

      Enum.each(6..10, fn i ->
        OutcomeTracker.record("p#{i}", "intent", "act", "failure")
      end)

      assert ThresholdAdapter.adjustment("intent") == 1.0
    end

    test "apply_adjustment works" do
      assert ThresholdAdapter.apply_adjustment(0.7, 0.9) == 0.63
      assert ThresholdAdapter.apply_adjustment(0.7, 1.2) == 0.84
    end
  end

  describe "PromptOptimizer" do
    test "records prompt variants" do
      PromptOptimizer.record("decomposition", "Break down: {{task}}", score: 0.8)
      PromptOptimizer.record("decomposition", "Decompose: {{task}}", score: 0.6)

      variants = PromptOptimizer.variants("decomposition")
      assert length(variants) == 2
      assert hd(variants).avg_score == 0.8
    end

    test "returns best prompt with enough samples" do
      PromptOptimizer.record("decomposition", "A", score: 0.9)
      PromptOptimizer.record("decomposition", "A", score: 0.9)
      PromptOptimizer.record("decomposition", "A", score: 0.9)
      PromptOptimizer.record("decomposition", "B", score: 0.6)
      PromptOptimizer.record("decomposition", "B", score: 0.6)
      PromptOptimizer.record("decomposition", "B", score: 0.6)

      best = PromptOptimizer.best_prompt("decomposition")
      assert best.prompt == "A"
      assert best.avg_score == 0.9
      assert best.uses == 3
    end

    test "returns nil for best prompt with too few samples" do
      PromptOptimizer.record("decomposition", "A", score: 0.9)
      PromptOptimizer.record("decomposition", "A", score: 0.9)

      assert PromptOptimizer.best_prompt("decomposition") == nil
    end
  end
end
