defmodule BotArmyLibraryLearning.Release do
  @moduledoc """
  Release tasks for database migrations.

  Migrations are run via the shared BotArmyLibraryRuntime.Ecto.MigrationRunner:

      eval 'BotArmyLibraryLearning.Release.migrate()'

  Called from Salt during bot deployment, before the bot starts.
  """

  def migrate do
    BotArmyLibraryRuntime.Ecto.MigrationRunner.run(
      repo_module: BotArmyLibraryLearning.Repo,
      app_module: :bot_army_library_learning
    )
  end
end
