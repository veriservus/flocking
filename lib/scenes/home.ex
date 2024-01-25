defmodule Flocking.Scene.Home do
  use Scenic.Scene
  require Logger

  alias Scenic.Graph

  import Scenic.Primitives
  # import Scenic.Components

  alias Scenic.Math.Vector2
  alias Flocking.Utils, as: U

  @boid_count 120

  defmodule Boid do
    @max_speed 3
    @max_force 0.05

    defstruct [
      :id,
      :pos,
      :velocity,
      :acceleration
    ]

    @type t :: %__MODULE__{
      id: integer(),
      pos: Vector2,
      velocity: Vector2,
      acceleration: Vector2
    }

    def apply_force(%{acceleration: acc}=boid, force) do
      %{boid | acceleration: Vector2.add(acc, force)}
    end

    def separate(boids, %{pos: boid_pos, velocity: boid_vel}) do
      desired_separation = 40

      {steer, count} = boids
      |> Enum.map(fn %{pos: pos} = a_boid ->
        {Vector2.distance(boid_pos, pos), a_boid}
      end)
      |> Enum.filter(fn {d, _a_boid} ->
        d > 0 and d < desired_separation
      end)
      |> Enum.reduce({{0,0}, 0}, fn {d, %{pos: pos}}, {steer, count} ->
        diff = Vector2.sub(boid_pos, pos)
          |> Vector2.normalize()
          |> Vector2.div(d)

        {Vector2.add(steer, diff), count + 1}
      end)

      steer = cond do
        count > 0 -> Vector2.div(steer, count)
        true -> steer
      end

      cond do
        Vector2.length(steer) > 0 ->
          steer
          |> Vector2.normalize()
          |> Vector2.mul(@max_speed)
          |> Vector2.sub(boid_vel)
          |> vector_limit(@max_force)
        true ->
          steer
      end
    end

    def align(boids, %{pos: boid_pos, velocity: velocity}) do
      neighbour_dist = 60

      {sum, count} = Enum.reduce(boids, {{0,0}, 0}, fn %{pos: pos, velocity: vel}, {sum, count} ->
        d = Vector2.distance(boid_pos, pos)

        cond do
          d > 0 and d < neighbour_dist -> {Vector2.add(sum, vel), count+2}
          true -> {sum, count}
        end

      end)

      if count > 0 do
        sum
        |> Vector2.div(count)
        |> Vector2.normalize()
        |> Vector2.mul(@max_speed)
        |> Vector2.sub(velocity)
        |> vector_limit(@max_force)
      else
        {0, 0}
      end
    end

    def cohere(boids, %{pos: boid_pos} = boid) do
      neighbour_dist = 60

      {sum, count} = Enum.reduce(boids, {{0,0}, 0}, fn %{pos: pos}, {sum, count} ->
        d = Vector2.distance(boid_pos, pos)

        cond do
          d > 0 and d < neighbour_dist -> {Vector2.add(sum, pos), count+1}
          true -> {sum, count}
        end
      end)

      if count > 0 do
        sum
        |> Vector2.div(count)
        |> vector_seek(boid)
      else
        {0, 0}
      end
    end

    def vector_seek(target, %{pos: position, velocity: vel}) do
      Vector2.sub(target, position)
      |> Vector2.normalize()
      |> Vector2.mul(@max_speed)
      |> Vector2.sub(vel)
      |> vector_limit(@max_force)
    end

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

    def update(%{pos: p, velocity: v, acceleration: a} = boid) do
      v = Vector2.add(v, a)
      v = vector_limit(v, @max_speed)
      p = Vector2.add(p, v)
      a = Vector2.mul(a, 0)

      %{boid | pos: p, velocity: v, acceleration: a}
    end

    def flock(boid, boids) do
      s = Boid.separate(boids, boid)
      a = Boid.align(boids, boid)
      c = Boid.cohere(boids, boid)

      s = Vector2.mul(s, 1.5)
      a = Vector2.mul(a, 1.0)
      c = Vector2.mul(c, 1.0)

      boid
        |> Boid.apply_force(s)
        |> Boid.apply_force(a)
        |> Boid.apply_force(c)

    end

    def draw(%Boid{id: id, pos: pos, velocity: {velx, vely}}, graph) do
      rot = :math.atan2(velx, vely)
      triangle(graph, {{0, 0}, {10, 40}, {20, 0}}, id: id, stroke: {1, :white}, fill: :white, translate: pos, rotate: -rot)
    end

    def wrap(%Boid{pos: {x, y}} = boid) do
      max_x = U.max_width()
      max_y = U.max_height()

      new_x = cond do
        x > max_x -> 0
        x < 0 -> max_x
        true -> x
      end

      new_y = cond do
        y > max_y -> 0
        y < 0 -> max_y
        true -> y
      end

      %{boid | pos: {new_x, new_y}}
    end
  end



  def init(scene, _param, _opts) do

    scene =
      scene
      |> assign(graph: Graph.build(), boids: make_boids())

    tick()

    {:ok, scene}
  end

  @spec handle_input(any(), any(), any()) :: {:noreply, any()}
  def handle_input(event, _context, scene) do
    Logger.info("Received event: #{inspect(event)}")
    {:noreply, scene}
  end

  defp rand_vel() do
    Enum.random(-1..1)
  end

  defp make_boids() do
    width = U.max_width()
    height = U.max_height()

    Enum.map(1..@boid_count, fn _ ->
      %Boid{
        id: System.unique_integer([:monotonic]),
        pos: {:rand.uniform(width), :rand.uniform(height)},
        velocity: {rand_vel(), rand_vel()},
        acceleration: {0, 0}
      }
    end)
  end

  defp tick() do
    me = self()
    SchedEx.run_in(
      fn expected_run_time -> Process.send(me, {:animate, expected_run_time}, []) end,
      10,
      repeat: true
    )
  end

  def handle_info({:animate, _}, %{assigns: %{boids: boids, graph: graph}} = scene) do
    boids = Enum.map(boids, fn boid ->
      boid
        |> Boid.flock(boids)
        |> Boid.update()
        |> Boid.wrap()
    end)

    graph =
      Enum.reduce(boids, graph, fn %{id: id} = boid, graph ->
        case Graph.get(graph, id) do
          []  -> Boid.draw(boid, graph)
          [_] -> Graph.modify(graph, id, fn graph ->
            Boid.draw(boid, graph)
          end)
        end
      end)

    scene =
      scene
      |> assign(graph: graph, boids: boids)
      |> push_graph(graph)

      {:noreply, scene}
  end
end
