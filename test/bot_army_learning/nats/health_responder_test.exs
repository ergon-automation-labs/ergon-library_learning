defmodule BotArmyLibraryLearning.NATS.HealthResponderTest do
  use ExUnit.Case
  @moduletag :nats

  alias BotArmyLibraryLearning.NATS.HealthResponder

  defp now_ms, do: System.monotonic_time(:millisecond)

  describe "health_payload/1" do
    test "reports healthy status for the learning service" do
      payload = HealthResponder.health_payload(now_ms())

      assert payload["status"] == "healthy"
      assert payload["service"] == "learning"
    end

    test "reports the compiled release version" do
      payload = HealthResponder.health_payload(now_ms())

      assert payload["version"] == Mix.Project.config()[:version]
    end

    test "computes uptime in seconds from the start time" do
      payload = HealthResponder.health_payload(now_ms() - 90_000)

      assert payload["uptime_seconds"] == 90
    end

    test "reports zero uptime for a process that just started" do
      payload = HealthResponder.health_payload(now_ms())

      assert payload["uptime_seconds"] == 0
    end

    test "timestamp is parseable ISO8601" do
      payload = HealthResponder.health_payload(now_ms())

      assert {:ok, _, _} = DateTime.from_iso8601(payload["timestamp"])
    end

    test "payload is JSON encodable" do
      assert {:ok, _} = now_ms() |> HealthResponder.health_payload() |> Jason.encode()
    end
  end
end
