defmodule PeriodicTest do
  use ExUnit.Case

  defmodule Dummy do
    def do_it(state) do
      { :ok, PeriodicTest.bump_state(state) }
    end

    def run(state) do
      do_it(state)
    end
  end


  test "runs an anonymous function every 5 ms" do
    Periodic.start_link(nil)
    Periodic.repeat(fn state -> { :ok, bump_state(state) } end, 5, create_name_and_state(:one))
    :timer.sleep(17)
    assert Agent.get(:state_of_one, &(&1)) in 3..4
    DynamicSupervisor.stop(Periodic)
  end


  test "runs a {m,f} every 10 ms" do
    Periodic.start_link(nil)
    Periodic.repeat({ Dummy, :do_it }, 10, create_name_and_state(:two))
    :timer.sleep(35)
    assert Agent.get(:state_of_two, &(&1)) in 3..4
    DynamicSupervisor.stop(Periodic)
  end

  test "runs a module every 20 ms" do
    Periodic.start_link(nil)
    Periodic.repeat(Dummy, 20, create_name_and_state(:three))
    :timer.sleep(70)
    assert Agent.get(:state_of_three, &(&1)) in 3..4
    DynamicSupervisor.stop(Periodic)
  end


  test "runs multiple tasks" do
    Periodic.start_link(nil)
    Periodic.repeat(Dummy, 10, create_name_and_state(:four_10))
    Periodic.repeat(Dummy, 20, create_name_and_state(:four_20))
    :timer.sleep(55)
    assert Agent.get(:state_of_four_10, &(&1)) in 5..6
    assert Agent.get(:state_of_four_20, &(&1)) in 2..3
    DynamicSupervisor.stop(Periodic)
  end

  test "honors an offset" do
    Periodic.start_link(nil)
    Periodic.repeat(Dummy, 10, [ {:offset, 50} |  create_name_and_state(:three) ])
    :timer.sleep(65)
    assert Agent.get(:state_of_three, &(&1)) == 2
    DynamicSupervisor.stop(Periodic)
  end
  #-----------+
  #  Helpers  |
  #-----------+

  defp create_name_and_state(name) do
    state_name = :"state_of_#{name}"
    { :ok, pid } = Agent.start_link(fn -> 0 end, name: state_name)
    [ name: name, state: { state_name, pid } ]
  end

  def bump_state({ state_name, pid }) do
    Agent.update(pid, fn n -> n + 1 end)
    { state_name, pid }
  end
end
