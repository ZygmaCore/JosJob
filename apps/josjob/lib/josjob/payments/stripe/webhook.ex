defmodule Josjob.Payments.Stripe.Webhook do
  @moduledoc """
  Verifikasi signature webhook Stripe (header `Stripe-Signature`).

  Skema Stripe: header `t=timestamp,v1=signature[,v1=...]`.
  signed_payload = `"\#{t}.\#{payload}"`,
  signature = HMAC-SHA256(secret, signed_payload) heksadesimal huruf kecil.

  `construct_event/4` membandingkan konstan-waktu dan menolak bila timestamp di
  luar toleransi (default 300 detik, mitigasi replay). Sukses -> `{:ok, event}`
  (payload sudah di-decode JSON).

  Opsi (untuk test): `:now` (unix detik) & `:tolerance` (detik).
  """
  import Bitwise

  @default_tolerance 300

  @spec construct_event(binary(), binary(), binary(), keyword()) ::
          {:ok, map()} | {:error, atom()}
  def construct_event(payload, signature_header, secret, opts \\ [])

  def construct_event(payload, signature_header, secret, opts)
      when is_binary(payload) and is_binary(signature_header) and is_binary(secret) and
             secret != "" do
    tolerance = Keyword.get(opts, :tolerance, @default_tolerance)
    now = Keyword.get(opts, :now, System.system_time(:second))

    with {:ok, timestamp, signatures} <- parse_header(signature_header),
         :ok <- check_timestamp(timestamp, now, tolerance),
         :ok <- verify_signature(payload, timestamp, signatures, secret),
         {:ok, event} <- decode(payload) do
      {:ok, event}
    end
  end

  def construct_event(_payload, _signature_header, _secret, _opts), do: {:error, :missing_input}

  defp parse_header(header) do
    parts =
      header
      |> String.split(",")
      |> Enum.map(&String.split(&1, "=", parts: 2))

    timestamp =
      Enum.find_value(parts, fn
        ["t", value] -> value
        _ -> nil
      end)

    signatures = for ["v1", value] <- parts, do: value

    case {timestamp && Integer.parse(timestamp), signatures} do
      {{ts, _rest}, [_ | _] = sigs} -> {:ok, ts, sigs}
      _ -> {:error, :invalid_signature_header}
    end
  end

  defp check_timestamp(timestamp, now, tolerance) do
    if abs(now - timestamp) <= tolerance do
      :ok
    else
      {:error, :timestamp_out_of_tolerance}
    end
  end

  defp verify_signature(payload, timestamp, signatures, secret) do
    expected =
      :hmac
      |> :crypto.mac(:sha256, secret, "#{timestamp}.#{payload}")
      |> Base.encode16(case: :lower)

    if Enum.any?(signatures, &secure_compare(&1, expected)) do
      :ok
    else
      {:error, :signature_mismatch}
    end
  end

  defp decode(payload) do
    case Jason.decode(payload) do
      {:ok, event} -> {:ok, event}
      _ -> {:error, :invalid_payload}
    end
  end

  # Perbandingan konstan-waktu tanpa perlu dep Plug pada app :josjob.
  defp secure_compare(left, right)
       when is_binary(left) and is_binary(right) and byte_size(left) == byte_size(right) do
    left
    |> :binary.bin_to_list()
    |> Enum.zip(:binary.bin_to_list(right))
    |> Enum.reduce(0, fn {a, b}, acc -> bor(acc, bxor(a, b)) end)
    |> Kernel.==(0)
  end

  defp secure_compare(_left, _right), do: false
end
