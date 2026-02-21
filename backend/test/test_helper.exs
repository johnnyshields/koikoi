# Try to connect to MongoDB and configure tests accordingly
mongo_available =
  try do
    config = Application.get_env(:koikoi, Koikoi.Repo, [])
    url = config[:url] || "mongodb://172.29.208.1:27017/koikoi_test"
    {:ok, conn} = Mongo.start_link(url: url)
    # Use find_one as a connection test instead of command
    Mongo.find_one(conn, "health_check", %{})
    GenServer.stop(conn)
    true
  rescue
    _ -> false
  catch
    _, _ -> false
  end

if mongo_available do
  IO.puts("MongoDB is available - running all tests")
else
  IO.puts("MongoDB is NOT available - skipping MongoDB-dependent tests")
  ExUnit.configure(exclude: [:mongodb])
end

ExUnit.start()
