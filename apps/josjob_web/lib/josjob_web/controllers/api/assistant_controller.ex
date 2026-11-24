defmodule JosjobWeb.Api.AssistantController do
  use JosjobWeb, :controller

  @max_message 2_000
  @max_history 10
  @context """
  JosJob is a platform for early-career job seekers. Implemented user features:
  - /jobs lists and details for active employer-posted vacancies; visitors may browse without signing in.
  - /applications supports applying and tracking hiring stages; account required.
  - /explore contains the learning catalog and course enrollment.
  - /coaching provides coach profiles, availability and one-on-one bookings.
  - /documents is the user's document library; CV/profile is in Dashboard > Curriculum Vitae.
  - Dashboard includes learning overview, jobs overview, applications, certificates and CV.
  - Hiring and coaching conversations are available from their relevant details.
  Users can register, complete onboarding, then use protected learning and career features.
  Only claim details present in this context. If a question asks for unavailable specifics,
  clearly say the information is not available and direct the user to the closest relevant page.
  Never invent vacancy details, prices, course contents, eligibility or user-specific data.
  Answer in the language used by the user. Keep answers concise and use Markdown when helpful.
  """

  def chat(conn, %{"messages" => messages}) when is_list(messages) do
    with :ok <- rate_limit(conn.remote_ip),
         {:ok, messages} <- validate_messages(messages),
         {:ok, answer} <- generate(messages) do
      json(conn, %{answer: answer})
    else
      {:error, :rate_limited} ->
        conn |> put_status(:too_many_requests) |> json(%{error: "rate_limited"})

      {:error, :invalid_messages} ->
        conn |> put_status(:bad_request) |> json(%{error: "invalid_messages"})

      {:error, :not_configured} ->
        conn |> put_status(:service_unavailable) |> json(%{error: "assistant_unavailable"})

      {:error, _reason} ->
        conn |> put_status(:service_unavailable) |> json(%{error: "assistant_unavailable"})
    end
  end

  def chat(conn, _params),
    do: conn |> put_status(:bad_request) |> json(%{error: "invalid_messages"})

  defp validate_messages(messages) when length(messages) in 1..@max_history do
    valid? =
      Enum.all?(messages, fn
        %{"role" => role, "content" => content}
        when role in ["user", "assistant"] and is_binary(content) and
               byte_size(content) in 1..@max_message ->
          String.trim(content) != ""

        _ ->
          false
      end)

    if valid? and List.last(messages)["role"] == "user",
      do: {:ok, messages},
      else: {:error, :invalid_messages}
  end

  defp validate_messages(_), do: {:error, :invalid_messages}

  defp generate(messages) do
    config = Application.get_env(:josjob_rag, :embeddings, [])
    key = config[:api_key]

    if is_binary(key) and key != "" do
      model = Application.get_env(:josjob_web, :assistant_model, "gemini-2.5-flash")

      contents =
        Enum.map(messages, fn message ->
          %{
            role: if(message["role"] == "assistant", do: "model", else: "user"),
            parts: [%{text: message["content"]}]
          }
        end)

      body = %{
        systemInstruction: %{parts: [%{text: @context}]},
        contents: contents,
        generationConfig: %{temperature: 0.2, maxOutputTokens: 700}
      }

      base = config[:base_url] || "https://generativelanguage.googleapis.com"
      url = "#{base}/v1beta/models/#{model}:generateContent"

      case Req.post(url, params: [key: key], json: body, receive_timeout: 30_000, retry: false) do
        {:ok, %{status: 200, body: %{"candidates" => [%{"content" => %{"parts" => parts}} | _]}}} ->
          answer =
            parts
            |> Enum.map(& &1["text"])
            |> Enum.filter(&is_binary/1)
            |> Enum.join("\n")
            |> String.trim()

          if answer == "", do: {:error, :empty_answer}, else: {:ok, answer}

        _ ->
          {:error, :provider_error}
      end
    else
      {:error, :not_configured}
    end
  rescue
    _ -> {:error, :provider_error}
  end

  defp rate_limit(ip) do
    if JosjobWeb.AssistantRateLimiter.allow?(ip), do: :ok, else: {:error, :rate_limited}
  end
end
