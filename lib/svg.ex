defmodule Svg do
  @moduledoc """
  Svg structure and helper functions.
  """

  alias Settings

  @type t :: %__MODULE__{
          xmlns: String.t(),
          xlink: String.t(),
          width: integer,
          height: integer,
          body: String.t(),
          rank_matrix: integer,
          qr_matrix: list(list(integer))
        }

  defstruct xmlns: "http://www.w3.org/2000/svg",
            xlink: "http://www.w3.org/1999/xlink",
            width: nil,
            height: nil,
            body: nil,
            rank_matrix: nil,
            qr_matrix: nil

  def create(
        coding_string,
        %Settings{background_color: bg, qrcode_color: qc, scale: scale} = settings
      ) do

    coding_string
      |> set_qr_matrix(%Svg{})
      |> construct_body(scale, qc)
      |> construct_svg(scale, bg)
  end

  def save({:ok, svg}, svg_name) do
    {:ok, file} = File.open(svg_name, [:write])

    IO.binwrite(file, svg)
    File.close(file)
  end

  def save(err) do
    err
  end

  defp set_qr_matrix(
         coding_string,
         %__MODULE__{qr_matrix: matrix, rank_matrix: rank} = svg
       ) do
    case get_matrix_qr(coding_string) do
      {:ok, matrix} -> {:ok, %{svg | qr_matrix: matrix, rank_matrix: length(matrix)}}
      {:error, msg} -> {:error, msg}
    end
  end

  defp construct_body({:ok, %__MODULE__{qr_matrix: matrix} = svg}, scale, qc) do
    body =
      matrix
      |> find_nonzero_element()
      |> Enum.map(&create_rect(&1, scale, qc))

    {:ok, %{svg | body: body}}
  end

  defp construct_body(err, _scale, _qc) do
    err
  end

  defp construct_svg(
         {:ok,
          %__MODULE__{
            xmlns: xmlns,
            xlink: xlink,
            width: w,
            height: h,
            body: body,
            rank_matrix: rank_matrix
          } = svg},
         scale,
         bg
       ) do
    svg =
      {:svg,
       %{
         xmlns: xmlns,
         xlink: xlink,
         width: rank_matrix * scale,
         height: rank_matrix * scale
       }, [background_rect(bg) | body]}
      |> XmlBuilder.generate()

    {:ok, svg}
  end

  defp construct_svg(err, _bg) do
    err
  end

  defp create_rect({x_pos, y_pos}, scale, color) do
    {:rect,
     %{width: scale, height: scale, x: scale * x_pos, y: scale * y_pos, fill: to_hex(color)}, nil}
  end

  defp background_rect(color) do
    {:rect, %{width: "100%", height: "100%", fill: to_hex(color)}, nil}
  end

  defp get_matrix_qr(coding_string) when byte_size(coding_string) <= 154 do
    matrix =
      QRCode.encode(coding_string).matrix
      |> Tuple.to_list()
      |> Enum.map(&Tuple.to_list/1)

    {:ok, matrix}
  end

  defp get_matrix_qr(coding_string) when is_nil(coding_string) do
    {:error, "You have to put coding string!"}
  end

  defp get_matrix_qr(coding_string) do
    {:error, "Binary too long."}
  end

  defp find_nonzero_element(matrix) do
    matrix
    |> Enum.with_index()
    |> Enum.map(fn {row, i} ->
      row
      |> Enum.with_index()
      |> Enum.reduce([], fn
        {0, _}, acc -> acc
        {1, j}, acc -> [{i, j} | acc]
      end)
    end)
    |> List.flatten()
  end

  defp to_hex(color) when is_tuple(color) do
    {r, g, b} = color

    "#" <>
      (r |> :binary.encode_unsigned() |> Base.encode16()) <>
      (g |> :binary.encode_unsigned() |> Base.encode16()) <>
      (b |> :binary.encode_unsigned() |> Base.encode16())
  end

  defp to_hex(color) do
    color
  end
end