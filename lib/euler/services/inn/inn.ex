defmodule Euler.Services.Inn do
  @moduledoc """
  Module wich represents functions to work with INN numbers
  """
  @inn_multiplers_10 [2, 4, 10, 3, 5, 9, 4, 6, 8]
  @inn_multiplers_12 [
    [7, 2, 4, 10, 3, 5, 9, 4, 6, 8],
    [3, 7, 2, 4, 10, 3, 5, 9, 4, 6, 8]
  ]

  def validate(inn) do
    with {:ok, inn, length} <- validate_length(inn),
         {:ok, numbers} <- parse_numbers(inn),
         {:ok, inn} <- validate_checksum(numbers, length) do
      {:valid, inn}
    else
      {:error, message} ->
        {:invalid, message}
    end
  end

  defp validate_length(inn) do
    case String.length(inn) do
      10 -> {:ok, inn, 10}
      12 -> {:ok, inn, 12}
      _ -> {:error, "Некорректная длинна ИНН"}
    end
  end

  defp parse_numbers(inn) do
    inn
    |> String.split("", trim: true)
    |> parse_numbers([])
  end

  defp parse_numbers([el | chars], list) do
    case Integer.parse(el) do
      :error ->
        {:error, "недопустимый символ"}

      {number, _} when number <= 9 ->
        parse_numbers(chars, [number | list])

      {number, _} ->
        {:error, "недопустимый символ #{el} #{number}"}
    end
  end

  defp parse_numbers([], list) do
    {:ok, Enum.reverse(list)}
  end

  defp validate_checksum(numbers, 10) do
    check = inn_control_digit(numbers, @inn_multiplers_10)

    if check != List.last(numbers) ->
      {:error, "неверное контрольное число"}
    else
      {:ok, numbers}
    end
  end

  defp validate_checksum(numbers, 12) do
    check1 = inn_control_digit(numbers, Enum.at(@inn_multiplers_12, 0))
    check2 = inn_control_digit(numbers, Enum.at(@inn_multiplers_12, 1))

    cond do
      check1 != Enum.at(numbers, 10) ->
        {:error, "неверное первое контрольное число"}

      check2 != Enum.at(numbers, 11) ->
        {:error, "неверное второе контрольное число"}

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
