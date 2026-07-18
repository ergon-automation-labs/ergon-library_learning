defmodule Mix.Tasks.Learning.Deck.New do
  @moduledoc """
  Create a new learning deck.

  Usage:
    mix learning.deck.new --name "Greek Vocabulary" --domain greek
    mix learning.deck.new --name "Spanish Verbs" --domain spanish --description "Conjugation drills"
  """

  use Mix.Task
  require Logger

  alias BotArmyLibraryLearning.Repo
  alias BotArmyLibraryLearning.Schemas.{Domain, Deck}

  @shortdoc "Create a new learning deck"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start", [])

    {opts, _} =
      OptionParser.parse!(args,
        strict: [name: :string, domain: :string, description: :string]
      )

    name = opts[:name]
    domain_name = opts[:domain]
    description = opts[:description]

    case validate_inputs(name, domain_name) do
      {:ok, _} ->
        create_deck(name, domain_name, description)

      {:error, reason} ->
        Mix.shell().error(reason)
        exit({:shutdown, 1})
    end
  end

  defp validate_inputs(name, domain) when is_nil(name) or is_nil(domain) do
    {:error, "Error: --name and --domain are required"}
  end

  defp validate_inputs(name, domain) do
    {:ok, {name, domain}}
  end

  defp create_deck(name, domain_name, description) do
    # Get or create domain
    domain = find_or_create_domain(domain_name)

    # Create deck
    changeset =
      Deck.changeset(%Deck{}, %{
        name: name,
        domain_id: domain.id,
        description: description,
        card_count: 0
      })

    case Repo.insert(changeset) do
      {:ok, deck} ->
        Mix.shell().info("")
        Mix.shell().info("✓ Deck created successfully")
        Mix.shell().info("")
        Mix.shell().info("  ID:     #{deck.id}")
        Mix.shell().info("  Name:   #{deck.name}")
        Mix.shell().info("  Domain: #{domain.name}")
        Mix.shell().info("")
        Mix.shell().info("Next: mix learning.card.new --deck-id #{deck.id} --front '...' --back '...'")
        Mix.shell().info("")

      {:error, changeset} ->
        Mix.shell().error("Error creating deck:")
        Enum.each(changeset.errors, fn {field, {msg, _}} ->
          Mix.shell().error("  #{field}: #{msg}")
        end)

        exit({:shutdown, 1})
    end
  end

  defp find_or_create_domain(domain_name) do
    case Repo.get_by(Domain, name: domain_name) do
      nil ->
        {:ok, domain} =
          Domain.changeset(%Domain{}, %{name: domain_name})
          |> Repo.insert()

        Mix.shell().info("Created domain: #{domain_name}")
        domain

      domain ->
        domain
    end
  end
end
