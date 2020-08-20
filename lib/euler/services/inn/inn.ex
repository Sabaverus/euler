defmodule Euler.Services.Inn do
  @moduledoc """
  Module wich represents functions to work with INN numbers
  """

  alias Euler.Repo, as: DB
  alias Euler.Services.Inn.History, as: History

  @inn_multiplers_10 [2, 4, 10, 3, 5, 9, 4, 6, 8]
  @inn_multiplers_12 [
    [7, 2, 4, 10, 3, 5, 9, 4, 6, 8],
    [3, 7, 2, 4, 10, 3, 5, 9, 4, 6, 8]
  ]


  defstruct raw: nil, numeric: nil, digits: [], entry: nil

  def checks_history(limit \\ 10) do
    History
    |> History.count(limit)
    |> History.order_desc()
    |> DB.all()
  end

  def validate(inn) do
    with {:ok, inn, length} <- validate_length(inn),
         {:ok, parsed} <- parse_numbers(inn),
         {:ok, _} <- validate_checksum(parsed.digits, length) do
      {:correct, parsed}
    else
      {:error, :invalid, error} ->
        {:invalid, error}

      {:error, :incorrect, error} ->
        {:incorrect, inn, error}
    end
  end

  defp validate_length(inn) do
    case String.length(inn) do
      10 -> {:ok, inn, 10}
      12 -> {:ok, inn, 12}
      _ -> {:error, :invalid, "ИНН может быть 10 или 12 символов в длину"}
    end
  end

  defp parse_numbers(inn) do
    inn
    |> String.split("", trim: true)
    |> parse_numbers([], %__MODULE__{
      raw: inn
    })
  end

  defp parse_numbers([el | chars], list, %__MODULE__{} = inn) do
    case Integer.parse(el) do
      {number, _} when number <= 9 ->
        parse_numbers(chars, [number | list], inn)

      _ ->
        {:error, :invalid, "недопустимый символ в номере ИНН"}
    end
  end

  defp parse_numbers([], list, %__MODULE__{} = inn) do
    parsed =
      inn
      |> Map.put(:numeric, Integer.parse(inn.raw))
      |> Map.put(:digits, Enum.reverse(list))

    {:ok, parsed}
  end

  defp validate_checksum(numbers, 10) do
    check = inn_control_digit(numbers, @inn_multiplers_10)

    if check != List.last(numbers) do
      {:error, :incorrect, "неверное контрольное число"}
    else
      {:ok, numbers}
    end
  end

  defp validate_checksum(numbers, 12) do
    check1 = inn_control_digit(numbers, Enum.at(@inn_multiplers_12, 0))
    check2 = inn_control_digit(numbers, Enum.at(@inn_multiplers_12, 1))

    cond do
      check1 != Enum.at(numbers, 10) ->
        {:error, :incorrect, "неверное первое контрольное число"}

      check2 != Enum.at(numbers, 11) ->
        {:error, :incorrect, "неверное второе контрольное число"}

      true ->
        {:ok, numbers}
    end
  end

  defp inn_control_digit(numbers, multiplers) do
    multiplers
    |> Enum.reduce({0, 0}, fn n, {i, sum} ->
      {i + 1, sum + Enum.at(numbers, i) * n}
    end)
    |> elem(1)
    |> rem(11)
    |> rem(10)
  end
end
