defmodule ReactiveStruct do
  @moduledoc """
  A DSL for creating structs with automatic dependency-based recomputation.

  ReactiveStruct provides a macro-based system for creating structs where some fields
  are automatically computed from other fields. When a dependency changes, all
  dependent computed fields are automatically recomputed in topological order.

  ## Key Features

  - **Automatic dependency tracking**: Fields are recomputed only when their dependencies change
  - **Topological sorting**: Computations are executed in the correct order to handle chains of dependencies
  - **Lazy evaluation**: Only affected fields are recomputed, not the entire struct
  - **Clean API**: Simple `new/1`, `update/2`, and `put/3` functions for struct manipulation

  ## Usage

  1. `use ReactiveStruct` in your module
  2. Define your struct with `defstruct`
  3. Define computed fields with `computed/3` macro
  4. Use `new/1` to create instances and `update/2` to modify them

  ## Computed Field Syntax

  Two syntaxes are supported:

      # Block syntax
      computed :field_name, deps: [:dep1, :dep2] do
        dep1 + dep2
      end

      # Inline syntax
      computed(:field_name, deps: [:dep1, :dep2], do: dep1 + dep2)

  ## Examples

  ### Basic Calculator

      iex> defmodule Calculator do
      ...>   use ReactiveStruct
      ...>
      ...>   defstruct [:a, :b, :sum, :product]
      ...>
      ...>   computed :sum, deps: [:a, :b] do
      ...>     a + b
      ...>   end
      ...>
      ...>   computed(:product, deps: [:a, :b], do: a * b)
      ...> end
      iex> calc = Calculator.new(%{a: 5, b: 3})
      iex> calc.sum
      8
      iex> calc.product
      15
      iex> updated = Calculator.update(calc, :a, 10)
      iex> updated.sum
      13
      iex> updated.product
      30

  ### String Processing with Helper Functions

      iex> defmodule StringProcessor do
      ...>   use ReactiveStruct
      ...>
      ...>   defstruct [:input, :processed, :length]
      ...>
      ...>   defp helper(value), do: String.upcase(value)
      ...>
      ...>   computed :processed, deps: [:input] do
      ...>     helper(input)
      ...>   end
      ...>
      ...>   computed(:length, deps: [:processed], do: String.length(processed))
      ...> end
      iex> processor = StringProcessor.new(%{input: "hello"})
      iex> processor.processed
      "HELLO"
      iex> processor.length
      5

  ### Keyword List Initialization

      iex> defmodule StringProcessor2 do
      ...>   use ReactiveStruct
      ...>   defstruct [:input, :processed, :length]
      ...>   defp helper(value), do: String.upcase(value)
      ...>   computed :processed, deps: [:input] do
      ...>     helper(input)
      ...>   end
      ...>   computed(:length, deps: [:processed], do: String.length(processed))
      ...> end
      iex> processor_kw = StringProcessor2.new(input: "world")
      iex> processor_kw.processed
      "WORLD"
      iex> processor_kw.length
      5

  ### Complex Dependency Chains

      iex> defmodule Chain do
      ...>   use ReactiveStruct
      ...>   defstruct [:base, :base2, :step1, :step2, :final]
      ...>   computed(:step1, deps: [:base, :base2], do: (base || 0) * 2 + (base2 || 0))
      ...>   computed(:step2, deps: [:step1], do: step1 + 10)
      ...>   computed(:final, deps: [:step2], do: step2 * step2)
      ...> end
      iex> chain = Chain.new(base: 3, base2: 1)
      iex> chain.final
      289
      iex> updated = Chain.update(chain, :base, 5)
      iex> updated.final
      441

  ## Generated API Functions

  When you `use ReactiveStruct`, the following functions are automatically generated:

  - `new/1` - Create a new instance with initial values
  - `update/2` - Update a single field
  - `update/2` - Update multiple fields (map or keyword list)
  - `put/3` - Alias for `update/2` with single field
  - `mermaid/0` - Generate a MermaidJS flowchart diagram of field dependencies

  ### API Examples

      iex> defmodule APITest do
      ...>   use ReactiveStruct
      ...>   defstruct [:x, :y, :sum]
      ...>   computed(:sum, deps: [:x, :y], do: (x || 0) + (y || 0))
      ...> end
      iex>
      iex> # Test new with all required fields provided
      iex> instance = APITest.new(x: 0, y: 0)
      iex> instance.sum
      0
      iex>
      iex> # Test multiple field updates
      iex> multi = APITest.update(instance, %{x: 10, y: 20})
      iex> multi.sum
      30
      iex>
      iex> # Test put function (alias for update)
      iex> put_result = APITest.put(multi, :x, 100)
      iex> put_result.sum
      120

  ### Mermaid Diagram Generation

      iex> defmodule MermaidTest do
      ...>   use ReactiveStruct
      ...>   defstruct [:a, :b, :sum, :product]
      ...>   computed(:sum, deps: [:a, :b], do: (a || 0) + (b || 0))
      ...>   computed(:product, deps: [:a, :b], do: (a || 0) * (b || 0))
      ...> end
      iex>
      iex> diagram = MermaidTest.mermaid()
      iex> diagram =~ "flowchart TD"
      true
      iex> diagram =~ "A[a]"
      true
      iex> diagram =~ "SUM[sum]"
      true
      iex> diagram =~ "A --> SUM"
      true
      iex> diagram =~ "A --> PRODUCT"
      true

  ## Error Handling

  ReactiveStruct will raise compilation errors for:
  - Circular dependencies between computed fields
  - References to non-existent struct fields in dependency lists

  Runtime errors may occur if:
  - Computed field functions raise exceptions
  - Dependencies are nil when not expected by computation logic

  ## Performance Characteristics

  - **Compilation time**: O(n²) for dependency analysis where n is number of computed fields
  - **Runtime update**: O(k) where k is number of affected computed fields
  - **Memory overhead**: Minimal - only stores computation metadata at compile time

  ## Implementation Notes

  ReactiveStruct uses compile-time macros to generate efficient computation functions.
  It performs topological sorting to ensure computations happen in the correct order
  and tracks dependencies to minimize unnecessary recomputations.

  The generated code includes:
  - Individual computation functions for each computed field
  - Dependency tracking and affected field calculation
  - Topological sorting for correct computation order
  - Public API functions (`new/1`, `update/2`, `put/3`)
  """

  @doc false
  defmacro __using__(opts) do
    allow_setting_computed_fields = Keyword.get(opts, :allow_setting_computed_fields, false)
    # Keep backwards compatibility
    allow_setting_computed_fields =
      Keyword.get(opts, :allow_updating_computed_fields, allow_setting_computed_fields)

    required_fields = Keyword.get(opts, :required_fields, [])

    quote do
      import ReactiveStruct, only: [computed: 2, computed: 3]
      @reactive_computations []
      @allow_setting_computed_fields unquote(allow_setting_computed_fields)
      @required_fields unquote(required_fields)
      @before_compile ReactiveStruct
    end
  end

  @doc """
  Defines a computed field that automatically updates when dependencies change.

  ## Parameters
  - field: The field name (atom)
  - opts: Options including :deps (list of dependency fields)
  - block: The computation block that can access dependency values directly

  ## Example
      computed :all_vms, deps: [:regions, :zones, :vm_count] do
        regions * zones * vm_count
      end
  """
  defmacro computed(field, opts, do: block) do
    add_computation(field, opts, block)
  end

  defmacro computed(field, opts) do
    block = Keyword.get(opts, :do)
    add_computation(field, opts, block)
  end

  defp add_computation(field, opts, block) do
    deps = Keyword.get(opts, :deps, [])

    quote do
      @reactive_computations [
        {unquote(field), unquote(deps), unquote(Macro.escape(block))} | @reactive_computations
      ]
    end
  end

  @doc false
  def generate_computation_functions(computations) do
    for {field, deps, computation} <- computations do
      function_name = String.to_atom("__compute_#{field}__")

      # Create parameter bindings for the function
      params =
        for dep <- deps do
          {dep, [], nil}
        end

      quote do
        def unquote(function_name)(unquote_splicing(params)) do
          unquote(computation)
        end
      end
    end
  end

  @doc false
  def generate_api_functions do
    quote do
      unquote_splicing(generate_api_function_definitions())
      unquote_splicing(generate_api_helper_functions())
    end
  end

  @doc false
  def generate_api_function_definitions do
    [
      quote do
        def new(attrs \\ %{}) do
          normalized_attrs = normalize_attrs(attrs)

          # Validate with schema using NimbleOptions
          validated_attrs = validate_attrs_with_schema(normalized_attrs)

          # Validate fields being set during initialization
          changed_fields = Map.keys(validated_attrs)
          validate_field_updates(changed_fields)

          struct = struct(__MODULE__, validated_attrs)

          # Only recompute fields that weren't explicitly set
          if @allow_setting_computed_fields do
            explicitly_set_fields = MapSet.new(Map.keys(validated_attrs))
            recompute_missing_computed_fields(struct, explicitly_set_fields)
          else
            recompute_all(struct)
          end
        end

        def update(struct, key, value) when is_atom(key) do
          update(struct, [{key, value}])
        end

        def update(struct, attrs) when is_list(attrs) or is_map(attrs) do
          attrs_list = normalize_attrs(attrs, as_list: true)
          changed_fields = Enum.map(attrs_list, &elem(&1, 0))

          validate_field_updates(changed_fields)

          struct
          |> apply_changes(attrs_list)
          |> recompute_dependencies(changed_fields)
        end

        def put(struct, key, value), do: update(struct, key, value)

        @doc """
        Generates a MermaidJS flowchart diagram showing field dependencies.

        Returns a string containing a MermaidJS flowchart that visualizes:
        - Input fields (blue): Fields that are not computed from others
        - Computed fields (purple): Fields computed from dependencies
        - Dependencies: Arrows showing which fields depend on others

        ## Example
            iex> YourModule.mermaid() |> IO.puts()
            flowchart TD
                A[field_a]
                B[field_b]
                C[computed_field]
                A --> C
                B --> C
                ...
        """
        def mermaid do
          ReactiveStruct.generate_mermaid_diagram(@computations, __MODULE__)
        end
      end
    ]
  end

  @doc false
  def generate_api_helper_functions do
    [
      quote do
        defp normalize_attrs(attrs, opts \\ []) do
          ReactiveStruct.normalize_attrs(attrs, opts)
        end

        defp apply_changes(struct, changes) do
          ReactiveStruct.apply_changes(struct, changes)
        end

        defp validate_field_updates(changed_fields) do
          ReactiveStruct.validate_field_updates(
            changed_fields,
            @allow_setting_computed_fields,
            @computations
          )
        end

        defp validate_attrs_with_schema(attrs) do
          ReactiveStruct.validate_attrs_with_schema(
            attrs,
            @required_fields,
            @computations,
            __MODULE__
          )
        end
      end
    ]
  end

  @doc false
  def generate_computation_helpers do
    quote do
      defp recompute_all(struct) do
        ReactiveStruct.recompute_all(struct, @computations, __MODULE__)
      end

      defp recompute_dependencies(struct, changed_fields) do
        ReactiveStruct.recompute_dependencies(struct, changed_fields, @computations, __MODULE__)
      end

      defp recompute_missing_computed_fields(struct, explicitly_set_fields) do
        ReactiveStruct.recompute_missing_computed_fields(
          struct,
          explicitly_set_fields,
          @computations,
          __MODULE__
        )
      end
    end
  end

  # Helper functions that don't need module attributes
  @doc false
  def normalize_attrs(attrs, opts \\ []) do
    if opts[:as_list] do
      normalize_attrs_to_list(attrs)
    else
      normalize_attrs_to_map(attrs)
    end
  end

  @doc false
  def normalize_attrs_to_list(attrs) when is_list(attrs), do: attrs
  def normalize_attrs_to_list(attrs) when is_map(attrs), do: Map.to_list(attrs)

  @doc false
  def normalize_attrs_to_map(attrs) when is_list(attrs), do: Enum.into(attrs, %{})
  def normalize_attrs_to_map(attrs) when is_map(attrs), do: attrs

  @doc false
  def apply_changes(struct, changes) do
    Enum.reduce(changes, struct, fn {key, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  @doc false
  def get_computed_fields(computations) do
    computations
    |> Enum.map(&elem(&1, 0))
    |> MapSet.new()
  end

  @doc false
  def get_input_fields(computations, struct_fields) do
    computed_fields = get_computed_fields(computations)

    # Input fields are all struct fields that are not computed
    MapSet.new(struct_fields)
    |> MapSet.difference(computed_fields)
  end

  @doc false
  def find_affected_computations_iterative(affected_fields, computations, acc) do
    newly_affected =
      computations
      |> Enum.filter(fn {field, deps, _} ->
        field not in affected_fields and
          Enum.any?(deps, &MapSet.member?(affected_fields, &1))
      end)

    case newly_affected do
      [] ->
        acc

      _ ->
        new_affected_fields =
          newly_affected
          |> Enum.map(&elem(&1, 0))
          |> MapSet.new()
          |> MapSet.union(affected_fields)

        find_affected_computations_iterative(
          new_affected_fields,
          computations,
          newly_affected ++ acc
        )
    end
  end

  @doc false
  def topological_sort_helper(graph, result, _visited) when map_size(graph) == 0 do
    Enum.reverse(result)
  end

  def topological_sort_helper(graph, result, visited) do
    {field, {deps, comp}} =
      Enum.find(graph, fn {_field, {deps, _comp}} ->
        Enum.all?(deps, fn dep ->
          not Map.has_key?(graph, dep) or MapSet.member?(visited, dep)
        end)
      end)

    new_graph = Map.delete(graph, field)
    new_visited = MapSet.put(visited, field)
    new_result = [{field, deps, comp} | result]

    topological_sort_helper(new_graph, new_result, new_visited)
  end

  @doc false
  def topological_sort(computations) do
    Enum.into(computations, %{}, fn {field, deps, comp} ->
      {field, {deps, comp}}
    end)
    |> topological_sort_helper([], MapSet.new())
  end

  @doc false
  def find_affected_computations(changed_fields, computations) do
    changed_set = MapSet.new(changed_fields)
    find_affected_computations_iterative(changed_set, computations, [])
  end

  @doc false
  def validate_field_updates(changed_fields, allow_setting_computed_fields, computations) do
    unless allow_setting_computed_fields do
      computed_fields = get_computed_fields(computations)
      invalid_fields = Enum.filter(changed_fields, &MapSet.member?(computed_fields, &1))

      if invalid_fields != [] do
        field_list = invalid_fields |> Enum.map_join(", ", &":#{&1}")

        raise ArgumentError,
              "Cannot set computed fields #{field_list}. " <>
                "Set `allow_setting_computed_fields: true` when using ReactiveStruct to enable this behavior."
      end
    end
  end

  @doc false
  def validate_attrs_with_schema(attrs, manual_required_fields, computations, module) do
    schema = build_schema_for_module(module, manual_required_fields, computations)
    attrs_as_keyword = normalize_attrs_to_list(attrs)

    case NimbleOptions.validate(attrs_as_keyword, schema) do
      {:ok, validated_attrs} ->
        Enum.into(validated_attrs, %{})

      {:error, %NimbleOptions.ValidationError{} = error} ->
        raise ArgumentError, "Invalid attributes: #{Exception.message(error)}"
    end
  end

  @doc false
  def build_schema_for_module(module, manual_required_fields, computations) do
    struct_fields = get_struct_fields(module)

    # Automatically detect input fields (fields used as dependencies but not computed)
    auto_required_fields = get_input_fields(computations, struct_fields)

    # Combine manual and auto-detected required fields
    all_required_fields =
      MapSet.union(
        MapSet.new(manual_required_fields),
        auto_required_fields
      )

    struct_fields
    |> Enum.map(fn field ->
      options = [type: :any]

      options =
        if MapSet.member?(all_required_fields, field) do
          [{:required, true} | options]
        else
          options
        end

      {field, options}
    end)
  end

  @doc false
  def recompute_all(struct, computations, module) do
    computation_order = topological_sort(computations)

    Enum.reduce(computation_order, struct, fn {field, deps, computation}, acc ->
      recompute_field(acc, field, deps, computation, module)
    end)
  end

  @doc false
  def recompute_dependencies(struct, changed_fields, computations, module) do
    affected_computations = find_affected_computations(changed_fields, computations)
    computation_order = topological_sort(affected_computations)

    Enum.reduce(computation_order, struct, fn {field, deps, computation}, acc ->
      recompute_field(acc, field, deps, computation, module)
    end)
  end

  @doc false
  def recompute_field(struct, field, deps, _computation, module) do
    function_name = String.to_atom("__compute_#{field}__")
    dep_values = Enum.map(deps, &Map.get(struct, &1))
    result = apply(module, function_name, dep_values)
    Map.put(struct, field, result)
  end

  @doc false
  def recompute_missing_computed_fields(struct, explicitly_set_fields, computations, module) do
    # Only recompute computed fields that weren't explicitly set
    computations_to_recompute =
      computations
      |> Enum.filter(fn {field, _deps, _computation} ->
        not MapSet.member?(explicitly_set_fields, field)
      end)

    computation_order = topological_sort(computations_to_recompute)

    Enum.reduce(computation_order, struct, fn {field, deps, computation}, acc ->
      recompute_field(acc, field, deps, computation, module)
    end)
  end

  @doc """
  Generates a MermaidJS flowchart diagram for the given computations.

  Takes a list of computations (field, dependencies, computation) and the module name
  to generate a flowchart showing the dependency relationships.
  """
  def generate_mermaid_diagram(computations, module) do
    struct_keys = get_struct_fields(module)
    {input_fields, computed_fields} = classify_fields(computations, struct_keys)

    [
      "flowchart TD",
      build_field_nodes(input_fields, "Input fields"),
      build_field_nodes(computed_fields, "Computed fields", include_separator: true),
      "",
      "    %% Dependencies",
      build_dependencies(computations),
      "",
      build_styling(),
      "",
      build_class_assignments(input_fields, computed_fields)
    ]
    |> List.flatten()
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp get_struct_fields(module) do
    struct(module) |> Map.keys() |> List.delete(:__struct__)
  rescue
    _ -> []
  end

  defp classify_fields(computations, struct_keys) do
    computed_fields = MapSet.new(computations, &elem(&1, 0))
    input_fields = MapSet.difference(MapSet.new(struct_keys), computed_fields)
    {input_fields, computed_fields}
  end

  defp build_field_nodes(fields, _label, opts \\ [])
  defp build_field_nodes(fields, _label, _opts) when map_size(fields) == 0, do: []

  defp build_field_nodes(fields, label, opts) do
    separator = if opts[:include_separator], do: [""], else: []
    nodes = fields |> MapSet.to_list() |> Enum.map(&"    #{format_field_node(&1)}") |> Enum.sort()

    separator ++ ["    %% #{label}"] ++ nodes
  end

  defp build_dependencies(computations) do
    computations
    |> Enum.flat_map(fn {field, deps, _} ->
      Enum.map(deps, fn dep -> "    #{format_field_id(dep)} --> #{format_field_id(field)}" end)
    end)
    |> Enum.sort()
  end

  @input_style "fill:#e1f5fe,stroke:#0277bd"
  @computed_style "fill:#f3e5f5,stroke:#7b1fa2"

  defp build_styling do
    [
      "    classDef inputField #{@input_style},stroke-width:2px",
      "    classDef computedField #{@computed_style},stroke-width:2px"
    ]
  end

  defp build_class_assignments(input_fields, computed_fields) do
    [
      build_class_assignment(input_fields, "inputField"),
      build_class_assignment(computed_fields, "computedField")
    ]
    |> Enum.reject(&(&1 == ""))
  end

  defp build_class_assignment(fields, _class_name) when map_size(fields) == 0, do: ""

  defp build_class_assignment(fields, class_name) do
    field_ids = fields |> MapSet.to_list() |> Enum.map_join(",", &format_field_id/1)
    "    class #{field_ids} #{class_name}"
  end

  defp format_field_node(field) do
    "#{format_field_id(field)}[#{field}]"
  end

  defp format_field_id(field) when is_atom(field) do
    field
    |> Atom.to_string()
    |> String.upcase()
    |> String.replace("_", "")
  end

  @doc false
  defmacro __before_compile__(env) do
    computations = Module.get_attribute(env.module, :reactive_computations) |> Enum.reverse()

    quote do
      @computations unquote(Macro.escape(computations))

      unquote_splicing(ReactiveStruct.generate_computation_functions(computations))
      unquote(ReactiveStruct.generate_api_functions())
      unquote(ReactiveStruct.generate_computation_helpers())
    end
  end
end
