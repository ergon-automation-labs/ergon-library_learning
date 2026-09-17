defmodule BotArmyLibraryLearning.OutcomeTrackerTest do
  use ExUnit.Case
  @moduletag :core

  alias BotArmyLibraryLearning.OutcomeTracker
  alias BotArmyLibraryLearning.ThresholdAdapter

  # These pin the library-level fix for the fleet's silent-data-loss class.
  #
  # `start_link/1` used to derive the registered name from `:repo`
  # (`:"#{repo}_outcome_tracker"`). Every client function defaults to the module
  # name, so a repo-only registration produced a process that no caller could
  # reach: `stats/2` crashed the caller (gtd's IntentEvaluator died every five
  # minutes in production) and `record/5` dropped outcomes with no log line.
  # The class is now impossible — `:repo` only selects the persistence repo.

  describe "registered name" do
    test "a repo-only registration lands on the module default" do
      start_supervised!({OutcomeTracker, repo: BotArmyLibraryLearning.Repo})

      assert Process.whereis(OutcomeTracker),
             "a tracker started with only :repo must be reachable at the library default"
    end

    test "the old derived name is never used" do
      start_supervised!({OutcomeTracker, repo: BotArmyLibraryLearning.Repo})

      refute Process.whereis(:"Elixir.BotArmyLibraryLearning.Repo_outcome_tracker"),
             "the :repo-derived name is the footgun this library removes"
    end

    test "an explicit :name wins over the default" do
      start_supervised!({OutcomeTracker, [name: :ot_custom, repo: BotArmyLibraryLearning.Repo]})

      assert Process.whereis(:ot_custom)
      refute Process.whereis(OutcomeTracker)
    end
  end

  describe "client calls default to the registered name" do
    test "record/4 is visible to stats/1" do
      start_supervised!({OutcomeTracker, repo: BotArmyLibraryLearning.Repo})

      OutcomeTracker.record("item-1", "factory", "approved", "pass")

      assert %{total: 1, correct: 1} = OutcomeTracker.stats("factory")
    end

    test "a custom-named tracker answers its own client calls" do
      start_supervised!({OutcomeTracker, [name: :ot_custom2, repo: BotArmyLibraryLearning.Repo]})

      OutcomeTracker.record("item-1", "factory", "approved", "pass", :ot_custom2)

      assert %{total: 1, correct: 1} = OutcomeTracker.stats("factory", :ot_custom2)
    end
  end

  describe "ThresholdAdapter.adjustment/2" do
    test "reads the default-named tracker with no options" do
      start_supervised!({OutcomeTracker, repo: BotArmyLibraryLearning.Repo})

      # No history → accuracy 0.0 → loosened.
      assert ThresholdAdapter.adjustment("factory") == 1.2
    end

    test "reads a custom-named tracker when given :server" do
      start_supervised!({OutcomeTracker, [name: :ot_custom3, repo: BotArmyLibraryLearning.Repo]})

      OutcomeTracker.record("item-1", "factory", "approved", "pass", :ot_custom3)

      # accuracy 1.0 > tighten_threshold → tightened. Without :server this call
      # reads the default name, which nothing registered → :noproc.
      assert ThresholdAdapter.adjustment("factory", server: :ot_custom3, tighten_threshold: 0.5) ==
               0.9
    end

    test "still accepts the pre-existing threshold overrides" do
      start_supervised!({OutcomeTracker, repo: BotArmyLibraryLearning.Repo})

      # No history → accuracy 0.0, below every loosen threshold, so the
      # override that applies here is :loosen_factor.
      assert ThresholdAdapter.adjustment("factory", loosen_factor: 1.5) == 1.5
    end
  end
end
