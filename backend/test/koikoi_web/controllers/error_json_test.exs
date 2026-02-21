defmodule KoikoiWeb.ErrorJSONTest do
  use KoikoiWeb.ConnCase, async: true

  test "renders 404" do
    assert KoikoiWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert KoikoiWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
