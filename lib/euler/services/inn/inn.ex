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
    with :ok <- validate_length(inn),
         :ok <- validate_symbols(inn) do
      :ok
    else
      error -> error
    end
  end

  defp validate_length(inn) do
    case String.length(inn) do
      10 -> :ok
      12 -> :ok
      _ -> {:error, %{type: :invalid, message: "ИНН может быть 10 или 12 символов в длину"}}
    end
  end

  defp validate_symbols(inn) do
    inn
    |> String.split("", trim: true)
    |> Enum.filter(fn s ->
      Integer.parse(s) == :error
    end)
    |> case do
      [] -> :ok
      _ -> {:error, %{type: :invalid, message: "недопустимые символы в номере ИНН"}}
    end
  end

  @spec parse(binary) ::
          Euler.Services.Inn.t()
          | {:error, %{message: bitstring(), type: :invalid}}
  def parse(inn) when is_bitstring(inn) do
    case validate(inn) do
      :ok -> parse_numbers(inn)
      error -> error
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
    {number, _} = Integer.parse(el)
    parse_numbers(chars, [number | list], inn)
  end

  defp parse_numbers([], list, %__MODULE__{} = inn) do
    {numeric, ""} = Integer.parse(inn.raw)

    inn
    |> Map.put(:numeric, numeric)
    |> Map.put(:digits, Enum.reverse(list))
  end

  @spec check(Euler.Services.Inn.t()) ::
          :ok | {:error, %{message: bitstring(), type: :incorrect}}
  def check(%__MODULE__{digits: digits}) when length(digits) == 10 do
    check = inn_control_digit(digits, @inn_multiplers_10)

    if check != List.last(digits) do
      {:error, %{type: :incorrect, message: "неверное контрольное число"}}
    else
      :ok
    end
  end

  def check(%__MODULE__{digits: digits}) when length(digits) == 12 do
    check1 = inn_control_digit(digits, Enum.at(@inn_multiplers_12, 0))
    check2 = inn_control_digit(digits, Enum.at(@inn_multiplers_12, 1))

    cond do
      check1 != Enum.at(digits, 10) ->
        {:error, %{type: :incorrect, message: "неверное первое контрольное число"}}

      check2 != Enum.at(digits, 11) ->
        {:error, %{type: :incorrect, message: "неверное второе контрольное число"}}

      true ->
        :ok
    end
  end

  def check(%__MODULE__{} = _inn) do
    raise ArgumentError, message: "Incorrect length of inn"
  end

  def check(_inn) do
    raise ArgumentError, message: "First argument must be struct of module #{__MODULE__}"
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
