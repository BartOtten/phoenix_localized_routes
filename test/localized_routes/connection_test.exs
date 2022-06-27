defmodule PhxLocalizedRoutesConnectionTests do
  use ExUnit.Case, async: true
  use MyAppWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "generated routes" do
    test "preserve native assigns", %{conn: conn} do
      conn = get(conn, "/europe/be/paginas/nieuw")
      assert Map.get(conn.assigns, :key) == :value
    end

    test "include configured assigns", %{conn: conn} do
      conn = get(conn, "/europe/be/paginas/nieuw")

      assert Map.get(conn.private, :phoenix_action) == :new
      assert Map.get(conn.private, :phoenix_controller) == MyAppWeb.PageController
      assert conn.path_info == ["europe", "be", "paginas", "nieuw"]

      assert Map.get(conn.assigns, :loc) == %{
               contact: "handel@example.be",
               locale: "nl",
               scope_helper: "europe_be"
             }
    end
  end

  describe "Normal Views and LiveViews" do
    test "share the same assigns", %{conn: conn} do
      conn = get(conn, "/europe/nl/producten")

      html = html_response(conn, 200)
      assert html =~ "Locale: nl"
      assert html =~ "Connected: false"
      assert html =~ "/europe/be/producten"

      {:ok, _view, html} = live(conn)
      assert html =~ "Locale: nl"
      assert html =~ "Connected: true"
      assert html =~ "/europe/be/producten"
    end

    test "render the correct links", %{conn: conn} do
      conn = get(conn, "/europe/nl/producten")

      html = html_response(conn, 200)

      assert html =~
               "<a data-phx-link=\"redirect\" data-phx-link-state=\"push\" href=\"/europe/nl/producten/nieuw\" id=\"redirect\">New Product</a>"

      assert html =~
               "<a data-phx-link=\"patch\" data-phx-link-state=\"push\" href=\"/europe/nl/producten/nieuw\" id=\"patch\">New Product</a>"

      assert html =~ "<a href=\"/europe/nl/producten/nieuw\" id=\"link\">New Product</a>"

      {:ok, _view, html} = live(conn)

      assert html =~
               "<a data-phx-link=\"redirect\" data-phx-link-state=\"push\" href=\"/europe/nl/producten/nieuw\" id=\"redirect\">New Product</a>"

      assert html =~
               "<a data-phx-link=\"patch\" data-phx-link-state=\"push\" href=\"/europe/nl/producten/nieuw\" id=\"patch\">New Product</a>"

      assert html =~ "<a href=\"/europe/nl/producten/nieuw\" id=\"link\">New Product</a>"
    end
  end

  describe "LiveViews" do
    test "redirect back to the localized route", %{conn: conn} do
      conn = get(conn, "/europe/nl/producten")
      {:ok, view, _html} = live(conn)

      assert view
             |> element("#patch")
             |> render_click() =~ "Modal"

      {:ok, modal_view, modal_html} = live(conn, "/europe/nl/producten/nieuw")
      assert modal_html =~ "Modal"

      modal_view
      |> element("form")
      |> render_submit(%{})

      assert_redirect(modal_view, "/europe/nl/producten", 30)
    end

    test "can render a route to root", %{conn: conn} do
      conn = get(conn, "/europe/nl/producten")

      html = html_response(conn, 200)

      assert html =~
               "<a href=\"/products\" id=\"link-\"> [] </a>"
    end
  end
end
