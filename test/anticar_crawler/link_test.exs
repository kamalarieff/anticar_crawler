defmodule AnticarCrawler.LinkTest do
  use AnticarCrawler.DataCase

  alias AnticarCrawler.Link

  describe "comments" do
    alias AnticarCrawler.Link.Comment

    @valid_attrs %{body: "some body", permalink: "some permalink"}
    @update_attrs %{body: "some updated body", permalink: "some updated permalink"}
    @invalid_attrs %{body: nil, permalink: nil}

    def comment_fixture(attrs \\ %{}) do
      {:ok, comment} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Link.create_comment()

      comment
    end

    test "list_comments/0 returns all comments" do
      comment = comment_fixture()
      assert Link.list_comments() == [comment]
    end

    test "get_comment!/1 returns the comment with given id" do
      comment = comment_fixture()
      assert Link.get_comment!(comment.id) == comment
    end

    test "create_comment/1 with valid data creates a comment" do
      assert {:ok, %Comment{} = comment} = Link.create_comment(@valid_attrs)
      assert comment.body == "some body"
      assert comment.permalink == "some permalink"
    end

    test "create_comment/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Link.create_comment(@invalid_attrs)
    end

    test "update_comment/2 with valid data updates the comment" do
      comment = comment_fixture()
      assert {:ok, %Comment{} = comment} = Link.update_comment(comment, @update_attrs)
      assert comment.body == "some updated body"
      assert comment.permalink == "some updated permalink"
    end

    test "update_comment/2 with invalid data returns error changeset" do
      comment = comment_fixture()
      assert {:error, %Ecto.Changeset{}} = Link.update_comment(comment, @invalid_attrs)
      assert comment == Link.get_comment!(comment.id)
    end

    test "delete_comment/1 deletes the comment" do
      comment = comment_fixture()
      assert {:ok, %Comment{}} = Link.delete_comment(comment)
      assert_raise Ecto.NoResultsError, fn -> Link.get_comment!(comment.id) end
    end

    test "change_comment/1 returns a comment changeset" do
      comment = comment_fixture()
      assert %Ecto.Changeset{} = Link.change_comment(comment)
    end
  end
end
