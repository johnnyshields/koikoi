defmodule Koikoi.Repo do
  @moduledoc """
  MongoDB repository wrapper using mongodb_driver directly.
  """

  def start_link(_opts \\ []) do
    config = Application.get_env(:koikoi, __MODULE__, [])
    url = config[:url] || "mongodb://localhost:27017/koikoi_dev"
    pool_size = config[:pool_size] || 10

    Mongo.start_link(
      url: url,
      name: :mongo,
      pool_size: pool_size
    )
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker
    }
  end

  def insert_one(collection, document, opts \\ []) do
    Mongo.insert_one(:mongo, collection, document, opts)
  end

  def insert_many(collection, documents, opts \\ []) do
    Mongo.insert_many(:mongo, collection, documents, opts)
  end

  def find_one(collection, filter, opts \\ []) do
    Mongo.find_one(:mongo, collection, filter, opts)
  end

  def find(collection, filter, opts \\ []) do
    Mongo.find(:mongo, collection, filter, opts)
  end

  def update_one(collection, filter, update, opts \\ []) do
    Mongo.update_one(:mongo, collection, filter, update, opts)
  end

  def update_many(collection, filter, update, opts \\ []) do
    Mongo.update_many(:mongo, collection, filter, update, opts)
  end

  def delete_one(collection, filter, opts \\ []) do
    Mongo.delete_one(:mongo, collection, filter, opts)
  end

  def delete_many(collection, filter, opts \\ []) do
    Mongo.delete_many(:mongo, collection, filter, opts)
  end

  def count_documents(collection, filter, opts \\ []) do
    case Mongo.count_documents(:mongo, collection, filter, opts) do
      {:ok, count} -> count
      count when is_integer(count) -> count
    end
  end

  def aggregate(collection, pipeline, opts \\ []) do
    Mongo.aggregate(:mongo, collection, pipeline, opts)
  end

  def create_index(collection, keys, opts \\ []) do
    Mongo.create_indexes(:mongo, collection, [%{key: keys, options: opts}])
  end
end
