defmodule StellarWeb.ErrorHTML do
  @moduledoc """
  Dipanggil endpoint saat terjadi error pada request HTML (lihat config/config.exs).

  Halaman 404 dibuat SELF-CONTAINED (punya `<head>` + CSS sendiri) supaya tetap
  ber-style walau `render_errors` memakai `layout: false` dan tak bergantung pada
  assign apa pun — aman sebagai halaman error.
  """
  use StellarWeb, :html

  # Halaman 404 custom (daisyUI). Dipakai untuk semua route/asset yang tak ada.
  def render("404.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>404 · Page not found</title>
        <link rel="stylesheet" href={~p"/assets/css/app.css"} />
      </head>
      <body>
        <div class="hero min-h-screen bg-base-200">
          <div class="hero-content text-center">
            <div class="max-w-md">
              <p class="text-7xl font-black text-primary">404</p>
              <h1 class="mt-4 text-2xl font-bold">Page not found</h1>
              <p class="mt-2 opacity-70">
                The URL you opened doesn't exist or has been moved.
              </p>
              <div class="mt-6 flex flex-wrap justify-center gap-3">
                <a href="/dashboard" class="btn btn-primary">Go to Dashboard</a>
                <a href="/" class="btn btn-ghost">Home</a>
              </div>
            </div>
          </div>
        </div>
      </body>
    </html>
    """
  end

  # Status lain (500, dsb.) tetap teks polos berbasis nama template,
  # mis. "500.html" -> "Internal Server Error".
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
