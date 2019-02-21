defmodule TdLmWeb.TagView do
  use TdLmWeb, :view
  alias TdLmWeb.TagView

  @relation_attributes [:source_id, :source_type, :target_id, :target_type, :context]

  def render("index.json", %{tags: tags}) do
    %{data: render_many(tags, TagView, "tag.json")}
  end

  def render("show.json", %{tag: tag}) do
    %{data: render_one(tag, TagView, "tag.json")}
  end

  def render("tag.json", %{tag: tag}) do
    %{id: tag.id,
      value: tag.value
    }
  end
end
