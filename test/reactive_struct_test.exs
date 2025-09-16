defmodule ReactiveStructTest do
  use ExUnit.Case
  doctest ReactiveStruct

  test "reactive struct basic functionality" do
    defmodule TestStruct do
      use ReactiveStruct

      defstruct [:x, :y, :sum]

      computed(:sum, fn %{x: x, y: y} ->
        x + y
      end)
    end

    struct = TestStruct.new(%{x: 1, y: 2})
    assert struct.sum == 3

    updated = TestStruct.merge(struct, :x, 10)
    assert updated.sum == 12
  end

  test "new() function accepts keyword lists" do
    defmodule KeywordTestStruct do
      use ReactiveStruct

      defstruct [:a, :b, :sum]

      computed(:sum, fn %{a: a, b: b} ->
        if a && b, do: a + b, else: nil
      end)
    end

    # Test with keyword list
    struct_kw = KeywordTestStruct.new(a: 10, b: 20)
    assert struct_kw.sum == 30

    # Test with map (should still work)
    struct_map = KeywordTestStruct.new(%{a: 5, b: 15})
    assert struct_map.sum == 20

    # Test with empty keyword list should now fail since all non-computed fields are required
    assert_raise ArgumentError, ~r/Invalid attributes:.*required.*(a|b)/, fn ->
      KeywordTestStruct.new([])
    end
  end

  test "computed fields cannot be set by default" do
    defmodule RestrictedStruct do
      use ReactiveStruct

      defstruct [:x, :y, :sum]

      computed(:sum, fn %{x: x, y: y} ->
        x + y
      end)
    end

    # Creating with input fields should work
    struct = RestrictedStruct.new(%{x: 1, y: 2})
    assert struct.sum == 3

    # Creating with computed fields should raise an error
    assert_raise ArgumentError, ~r/Cannot set computed fields :sum/, fn ->
      RestrictedStruct.new(%{x: 1, y: 2, sum: 100})
    end

    # Updating input fields should work
    updated = RestrictedStruct.merge(struct, :x, 10)
    assert updated.sum == 12

    # Updating computed fields should raise an error
    assert_raise ArgumentError, ~r/Cannot set computed fields :sum/, fn ->
      RestrictedStruct.merge(struct, :sum, 100)
    end

    # Multiple field updates with computed field should also raise an error
    assert_raise ArgumentError, ~r/Cannot set computed fields :sum/, fn ->
      RestrictedStruct.merge(struct, %{x: 5, sum: 100})
    end
  end

  test "computed fields can be set when explicitly allowed" do
    defmodule AllowedStruct do
      use ReactiveStruct, allow_setting_computed_fields: true

      defstruct [:x, :y, :sum]

      computed(:sum, fn %{x: x, y: y} ->
        x + y
      end)
    end

    # Creating with computed fields should now work
    struct = AllowedStruct.new(%{x: 1, y: 2, sum: 100})
    assert struct.x == 1
    assert struct.y == 2
    assert struct.sum == 100

    # Updating computed fields should also work
    updated = AllowedStruct.merge(struct, :sum, 200)
    assert updated.sum == 200

    # Multiple field updates with computed field should also work
    updated2 = AllowedStruct.merge(struct, %{x: 5, sum: 50})
    assert updated2.x == 5
    assert updated2.sum == 50
  end

  test "backwards compatibility with allow_updating_computed_fields" do
    defmodule BackwardsCompatStruct do
      use ReactiveStruct, allow_updating_computed_fields: true

      defstruct [:x, :y, :sum]

      computed(:sum, fn %{x: x, y: y} ->
        x + y
      end)
    end

    # Old option name should still work
    struct = BackwardsCompatStruct.new(%{x: 1, y: 2, sum: 100})
    assert struct.sum == 100

    updated = BackwardsCompatStruct.merge(struct, :sum, 200)
    assert updated.sum == 200
  end

  test "nimble_options validation with automatic required fields" do
    defmodule AutoRequiredStruct do
      use ReactiveStruct

      defstruct [:name, :age, :display_name]

      computed(:display_name, fn %{name: name, age: age} ->
        "#{name} (#{age})"
      end)
    end

    # Test valid attributes - all non-computed fields are required
    valid_struct = AutoRequiredStruct.new(%{name: "John", age: 30})
    assert valid_struct.name == "John"
    assert valid_struct.age == 30
    assert valid_struct.display_name == "John (30)"

    # Test with keyword list
    valid_kw = AutoRequiredStruct.new(name: "Jane", age: 25)
    assert valid_kw.name == "Jane"
    assert valid_kw.display_name == "Jane (25)"

    # Test missing required field should raise - name is automatically required
    assert_raise ArgumentError, ~r/Invalid attributes:.*required.*name/, fn ->
      AutoRequiredStruct.new(%{age: 30})
    end

    # Test missing required field should raise - age is automatically required
    assert_raise ArgumentError, ~r/Invalid attributes:.*required.*age/, fn ->
      AutoRequiredStruct.new(%{name: "John"})
    end

    # Test empty map should raise for both automatically required fields
    assert_raise ArgumentError, ~r/Invalid attributes:/, fn ->
      AutoRequiredStruct.new(%{})
    end
  end

  test "manual required fields combined with automatic detection" do
    defmodule MixedRequiredStruct do
      use ReactiveStruct, required_fields: [:extra_required]

      defstruct [:name, :age, :extra_required, :display_name]

      computed(:display_name, fn %{name: name, age: age} ->
        "#{name} (#{age})"
      end)
    end

    # All non-computed fields should be required (name, age, extra_required)
    valid_struct = MixedRequiredStruct.new(%{name: "John", age: 30, extra_required: "value"})
    assert valid_struct.name == "John"
    assert valid_struct.display_name == "John (30)"

    # Missing any non-computed field should raise
    assert_raise ArgumentError, ~r/Invalid attributes:.*required.*extra_required/, fn ->
      MixedRequiredStruct.new(%{name: "John", age: 30})
    end
  end

  test "nimble_options validation with unknown fields" do
    defmodule SimpleStruct do
      use ReactiveStruct

      defstruct [:x, :y]
    end

    # Test that valid fields work
    struct = SimpleStruct.new(%{x: 1, y: 2})
    assert struct.x == 1
    assert struct.y == 2

    # Test that unknown fields are rejected by NimbleOptions
    assert_raise ArgumentError, ~r/Invalid attributes:.*unknown options.*:unknown/, fn ->
      SimpleStruct.new(%{x: 1, y: 2, unknown: "rejected"})
    end
  end

  test "nimble_options schema generation" do
    defmodule SchemaTestStruct do
      use ReactiveStruct

      defstruct [:input_field, :optional_field, :computed]

      computed(:computed, fn %{input_field: input_field} ->
        input_field * 2
      end)
    end

    # Create a mock computations list like what would be stored in @computations
    mock_computations = [
      {:computed, [:input_field], fn %{input_field: input_field} -> input_field * 2 end}
    ]

    # Test the schema generation function directly
    schema = ReactiveStruct.build_schema_for_module(SchemaTestStruct, [], mock_computations)

    # Should have entries for all struct fields
    schema_keys = Keyword.keys(schema)
    assert :input_field in schema_keys
    assert :optional_field in schema_keys
    assert :computed in schema_keys

    # All non-computed fields should be required automatically
    input_field_options = Keyword.get(schema, :input_field)
    assert Keyword.get(input_field_options, :required) == true

    optional_field_options = Keyword.get(schema, :optional_field)
    assert Keyword.get(optional_field_options, :required) == true

    # Computed field should not be required
    computed_options = Keyword.get(schema, :computed)
    assert Keyword.get(computed_options, :required) != true
  end
end
