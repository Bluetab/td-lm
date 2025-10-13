defmodule TdLmWeb.SearchView do
  use TdLmWeb, :view

  def render("show.json", %{results: results, scroll_id: scrol_id}) do
    %{
      data: results,
      scroll_id: scrol_id
    }
  end

  def render("show.json", %{results: results}) do
    %{
      data: results
    }
  end
end
