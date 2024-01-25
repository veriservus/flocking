defmodule Flocking.Scene.Home do
  use Scenic.Scene
  require Logger

  alias Scenic.Graph
  alias Flocking.Boid

  @boid_count 120

  def init(scene, _param, _opts) do
    scene =
      scene
      |> assign(graph: Graph.build(), boids: Boid.make_boids(@boid_count))

    tick()

    {:ok, scene}
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
