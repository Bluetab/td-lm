defmodule TdLmWeb.ErrorView do
  use TdLmWeb, :view

  def render("400.json", _assigns) do
    %{errors: %{detail: "Bad Request"}}
  end

  def render("401.json", _assigns) do
    %{errors: %{detail: "Unauthorized"}}
  end

  def render("403.json", _assigns) do
    %{errors: %{detail: "Forbidden"}}
  end

  def render("404.json", _assigns) do
    %{errors: %{detail: "Not Found"}}
  end

  def render("422.json", _assigns) do
    %{errors: %{detail: "Unprocessable Entity"}}
  end

  def render("500.json", _assigns) do
    %{errors: %{detail: "Internal Server Error"}}
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, assigns) do
    render("500.json", assigns)
  end
end
