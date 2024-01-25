defmodule Flocking.Utils do
  def max_width do
    {w, _} = Application.get_env(:flocking, :viewport)[:size]
    w
  end

  def max_height do
    {_, h} = Application.get_env(:flocking, :viewport)[:size]
    h
  end
end
