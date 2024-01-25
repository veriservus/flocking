defmodule Flocking.Utils do
  alias Scenic.Math.Vector2

  def vector_limit(vector, scalar) do
    magSq = Vector2.length_squared(vector)
    cond do
      magSq > scalar * scalar ->
        vector
          |> Vector2.div(Vector2.length(vector))
          |> Vector2.mul(scalar)
      true -> vector
    end
  end

  def vector_seek(target, position, velocity, opts \\ [max_speed: 3, max_force: 0.05]) do
    Vector2.sub(target, position)
    |> Vector2.normalize()
    |> Vector2.mul(opts[:max_speed])
    |> Vector2.sub(velocity)
    |> vector_limit(opts[:max_force])
  end

  def max_width do
    {w, _} = Application.get_env(:flocking, :viewport)[:size]
    w
  end

  def max_height do
    {_, h} = Application.get_env(:flocking, :viewport)[:size]
    h
  end
end
