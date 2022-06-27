defmodule PhxLocalizedRoutes.ScopesTest do
  use ExUnit.Case
  alias PhxLocalizedRoutes.Scopes
  alias PhxLocalizedRoutes.Fixtures, as: F

  @scopes_with_map_assign F.scopes_with_map_assign()
  @scopes_precomputed F.scopes_precomputed()
  @scopes F.scopes()
  @scopes_flat F.scopes_flat()

  test "add_precomputed_values!/1 with map assign adds precomputed values correctly" do
    assert Scopes.add_precomputed_values!(@scopes_with_map_assign) == @scopes_precomputed
  end

  test "add_precomputed_values!/1 with struct assign adds precomputed values correctly" do
    assert Scopes.add_precomputed_values!(@scopes) == @scopes_precomputed
  end

  test "flatten/1 returns a flat version of scopes scopes" do
    assert Scopes.flatten(@scopes_precomputed) == @scopes_flat
  end
end
