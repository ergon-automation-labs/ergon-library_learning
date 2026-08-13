import Config

# Test configuration uses isolated test database with SQL Sandbox
# This allows parallel test execution with transaction isolation
config :bot_army_library_learning, BotArmyLibraryLearning.Repo,
  database: System.get_env("BOT_ARMY_LEARNING_TEST_DB_NAME", "ergon_learning_test"),
  hostname: System.get_env("BOT_ARMY_LEARNING_DB_HOST", "localhost"),
  port: String.to_integer(System.get_env("BOT_ARMY_LEARNING_DB_PORT", "30003")),
  username: System.get_env("BOT_ARMY_LEARNING_DB_USER", "postgres"),
  password: System.get_env("BOT_ARMY_LEARNING_DB_PASSWORD", "postgres"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1

# In test mode, CardStore and SessionManager are not started (see application.ex @env guard)
# Phase 2: handler integration tests will use mocked stores via dependency injection
