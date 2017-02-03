defmodule ConformUtilsTest do
  use ExUnit.Case, async: true
  doctest Conform.Utils

  test "list of tuples" do
    settings = [rooms: [{"one", [:one]}, {"two", [:two]}]]
    assert Conform.Utils.merge(settings, []) == settings
    assert Conform.Utils.merge([], settings) == settings
    assert Conform.Utils.merge(settings, settings) == settings
  end

  test "list of ips" do
    ips = [ips: [{"127.0.0.1", "8001"}, {"::1", "8002"}]]
    assert Conform.Utils.merge(ips, []) == ips
    assert Conform.Utils.merge([], ips) == ips
    assert Conform.Utils.merge(ips, ips) == ips
  end

  test "#107" do
    assert [a: [1,2,3,4,5]] = Conform.Utils.merge([a: [1,2,3,4]], [a: [4,5]])
    assert [a: ["1","2","3","4","5"]] = Conform.Utils.merge([a: ["1","2","3","4"]], [a: ["4","5"]])
  end
end
