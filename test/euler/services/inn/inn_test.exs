defmodule EulerWeb.InnServiceTest do
  use Euler.DataCase

  alias Euler.Services.Inn, as: Inn

  @correct_10 "7830002293"
  @correct_12 "500100732259"

  ############## Validating ###############

  test "Validate correct inn number 10 digits" do
    assert :ok == Inn.validate(@correct_10)
  end

  test "Validate correct inn number 12 digits" do
    assert :ok == Inn.validate(@correct_12)
  end

  test "Incorrect inn number 10 digits control digit" do
    {:error, %{type: type}} = Inn.validate("78300022937")
    assert :invalid == type
  end

  test "Incorrect inn symbols" do
    {:error, %{type: type}} = Inn.validate(" 78g0 .22!3")
    assert :invalid == type
  end

  test "Invalid inn length 4 digits" do
    {:error, %{type: type}} = Inn.validate("12345")
    assert :invalid == type
  end

  test "Invalid inn length 11 digits" do
    {:error, %{type: type}} = Inn.validate("12345678901")
    assert :invalid == type
  end

  ############## Parsing ###############

  test "Parsing correct inn 10 digits" do
    %Inn{} = parsed = Inn.parse(@correct_10)
    assert @correct_10 == parsed.raw
    assert 7_830_002_293 == parsed.numeric
    assert [7, 8, 3, 0, 0, 0, 2, 2, 9, 3] == parsed.digits
  end

  test "Parsing correct inn 12 digits" do
    %Inn{} = parsed = Inn.parse(@correct_12)
    assert @correct_12 == parsed.raw
    assert 500_100_732_259 == parsed.numeric
    assert [5, 0, 0, 1, 0, 0, 7, 3, 2, 2, 5, 9] == parsed.digits
  end

  test "Parsing incorrect inn 10 digits" do
    %Inn{} = parsed = Inn.parse("7830002290")
    assert "7830002290" == parsed.raw
    assert 7_830_002_290 == parsed.numeric
    assert [7, 8, 3, 0, 0, 0, 2, 2, 9, 0] == parsed.digits
  end

  test "Parsing incorrect inn 12 digits" do
    %Inn{} = parsed = Inn.parse("500100732250")
    assert "500100732250" == parsed.raw
    assert 500_100_732_250 == parsed.numeric
    assert [5, 0, 0, 1, 0, 0, 7, 3, 2, 2, 5, 0] == parsed.digits
  end

  test "Parsing invalid inn symbols" do
    {:error, %{type: type}} = Inn.parse(" 78g0 .22!3")
    assert :invalid == type
  end

  test "Parsing invalid inn length 4 digits" do
    {:error, %{type: type}} = Inn.parse("12345")
    assert :invalid == type
  end

  test "Parsing invalid inn length 11 digits" do
    {:error, %{type: type}} = Inn.parse("12345678901")
    assert :invalid == type
  end

  ############## Checking ###############

  test "Check correct inn number 10 digits" do
    parsed = Inn.parse(@correct_10)
    assert :ok == Inn.check(parsed)
  end

  test "Check correct inn number 12 digits" do
    parsed = Inn.parse(@correct_12)
    assert :ok == Inn.check(parsed)
  end

  test "Check incorrect inn number 12 digits first control digit" do
    parsed = Inn.parse("500100732249")
    {:error, %{type: type}} = Inn.check(parsed)
    assert :incorrect == type
  end

  test "Check incorrect inn number 12 digits second control digit" do
    parsed = Inn.parse("500100732257")
    {:error, %{type: type}} = Inn.check(parsed)
    assert :incorrect == type
  end
end
