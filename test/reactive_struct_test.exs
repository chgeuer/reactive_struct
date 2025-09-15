defmodule ReactiveStructTest do
  use ExUnit.Case
  doctest ReactiveStruct

  test "reactive struct basic functionality" do
    defmodule TestStruct do
      use ReactiveStruct

      defstruct [:x, :y, :sum]

      computed :sum, deps: [:x, :y] do
        x + y
      end
    end

    struct = TestStruct.new(%{x: 1, y: 2})
    assert struct.sum == 3

    updated = TestStruct.update(struct, :x, 10)
    assert updated.sum == 12
  end

  test "new() function accepts keyword lists" do
    defmodule KeywordTestStruct do
      use ReactiveStruct

      defstruct [:a, :b, :sum]

      computed :sum, deps: [:a, :b] do
        if a && b, do: a + b, else: nil
      end
    end

    # Test with keyword list
    struct_kw = KeywordTestStruct.new(a: 10, b: 20)
    assert struct_kw.sum == 30

    # Test with map (should still work)
    struct_map = KeywordTestStruct.new(%{a: 5, b: 15})
    assert struct_map.sum == 20

    # Test with empty keyword list
    struct_empty = KeywordTestStruct.new([])
    assert struct_empty.a == nil
    assert struct_empty.sum == nil
  end
end
