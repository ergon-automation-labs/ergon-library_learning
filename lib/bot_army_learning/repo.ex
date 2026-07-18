defmodule BotArmyLibraryLearning.Repo do
  @moduledoc """
  Ecto Repository for the Learning bot.

  Provides database access for domains, decks, cards, reviews, and sessions with PostgreSQL backend.
  """

  use Ecto.Repo,
    otp_app: :bot_army_library_learning,
    adapter: Ecto.Adapters.Postgres
end
