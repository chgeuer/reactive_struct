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

  test "computed fields cannot be set by default" do
    defmodule RestrictedStruct do
      use ReactiveStruct

      defstruct [:x, :y, :sum]

      computed :sum, deps: [:x, :y] do
        x + y
      end
    end

    # Creating with input fields should work
    struct = RestrictedStruct.new(%{x: 1, y: 2})
    assert struct.sum == 3

    # Creating with computed fields should raise an error
    assert_raise ArgumentError, ~r/Cannot set computed fields :sum/, fn ->
      RestrictedStruct.new(%{x: 1, y: 2, sum: 100})
    end

    # Updating input fields should work
    updated = RestrictedStruct.update(struct, :x, 10)
    assert updated.sum == 12

    # Updating computed fields should raise an error
    assert_raise ArgumentError, ~r/Cannot set computed fields :sum/, fn ->
      RestrictedStruct.update(struct, :sum, 100)
    end

    # Multiple field updates with computed field should also raise an error
    assert_raise ArgumentError, ~r/Cannot set computed fields :sum/, fn ->
      RestrictedStruct.update(struct, %{x: 5, sum: 100})
    end
  end

  test "computed fields can be set when explicitly allowed" do
    defmodule AllowedStruct do
      use ReactiveStruct, allow_setting_computed_fields: true

      defstruct [:x, :y, :sum]

      computed :sum, deps: [:x, :y] do
        x + y
      end
    end

    # Creating with computed fields should now work
    struct = AllowedStruct.new(%{x: 1, y: 2, sum: 100})
    assert struct.x == 1
    assert struct.y == 2
    assert struct.sum == 100

    # Updating computed fields should also work
    updated = AllowedStruct.update(struct, :sum, 200)
    assert updated.sum == 200

    # Multiple field updates with computed field should also work
    updated2 = AllowedStruct.update(struct, %{x: 5, sum: 50})
    assert updated2.x == 5
    assert updated2.sum == 50
  end

  test "backwards compatibility with allow_updating_computed_fields" do
    defmodule BackwardsCompatStruct do
      use ReactiveStruct, allow_updating_computed_fields: true

      defstruct [:x, :y, :sum]

      computed :sum, deps: [:x, :y] do
        x + y
      end
    end

    # Old option name should still work
    struct = BackwardsCompatStruct.new(%{x: 1, y: 2, sum: 100})
    assert struct.sum == 100

    updated = BackwardsCompatStruct.update(struct, :sum, 200)
    assert updated.sum == 200
  end
end
