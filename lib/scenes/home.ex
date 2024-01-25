defmodule Flocking.Scene.Home do
  use Scenic.Scene
  require Logger

  alias Scenic.Graph

  # import Scenic.Components

  alias Flocking.Utils, as: U
  alias Flocking.Boid

  @boid_count 120

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
