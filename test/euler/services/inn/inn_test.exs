defmodule EulerWeb.PageControllerTest do
  use Euler.DataCase

  alias Euler.Services.Inn, as: Inn

  test "Validate correct inn number 10 digits" do
    {status, _} = Inn.validate("7830002293")
    assert :valid == status
  end

  test "Validate correct inn number 12 digits" do
    {status, _} = Inn.validate("500100732259")
    assert :valid == status
  end

  test "Incorrect inn number 10 digits control digit" do
    {status, _} = Inn.validate("78300022937")
    assert :invalid == status
  end

  test "Incorrect inn symbols" do
    {status, _} = Inn.validate(" 78g0 .22!3")
    assert :invalid == status
  end

  test "Incorrect inn length 4 digits" do
    {status, _} = Inn.validate("12345")
    assert :invalid == status
  end

  test "Incorrect inn length 11 digits" do
    {status, _} = Inn.validate("12345678901")
    assert :invalid == status
  end

  test "Validate incorrect inn number 12 digits first control digit" do
    {status, _} = Inn.validate("500100732249")
    assert :invalid == status
  end

  test "Validate incorrect inn number 12 digits second control digit" do
    {status, _} = Inn.validate("500100732257")
    assert :invalid == status
  end
end
