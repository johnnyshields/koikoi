defmodule Koikoi.Seeds do
  @moduledoc """
  Main entry point for database seeding.
  Run with: mix run -e "Koikoi.Seeds.run()"
  """

  require Logger

  def run do
    Logger.info("=== Starting Koikoi database setup and seeding ===")

    Koikoi.Seeds.Setup.run()
    Koikoi.Seeds.TagsCatalog.run()
    Koikoi.Seeds.TestUsers.run()

    Logger.info("=== Koikoi database setup and seeding complete ===")
  end
end
