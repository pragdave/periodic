defmodule Periodic.Runner do
  use GenServer

  def start_link({ task_spec, interval, options }) when is_list(options) do
    start_opts = case options[:name] do
                   nil -> []
                   name -> [ name: name ]
    end
    GenServer.start_link(__MODULE__, { task_spec, interval, options }, start_opts)
  end

  def init({ task_spec, interval, options }) do
    task_state = %{
      interval: interval,
      offset:   options[:offset] || 0,
      task:     task_spec,
      state:    options[:state]
    }
    :timer.send_after(task_state.offset, :trigger)
    { :ok, task_state }
  end

  def handle_info(:trigger, task_state) do

    started = now_ms()

    case run_function(task_state.task, task_state.state) do
    { :ok, new_state } ->
      next_time = task_state.interval - (now_ms() - started)
      :timer.send_after(next_time, :trigger)
      { :noreply, %{ task_state | state: new_state }}

    { :change_interval, interval, new_state } ->
      next_time = interval - (now_ms() - started)
      :timer.send_after(next_time, :trigger)
      { :noreply, %{ task_state | state: new_state, interval: interval }}


    { :stop, reason } ->
      { :stop, reason, task_state }

    other ->
      { :stop, :error, other }
    end
  end

  defp run_function({m, f}, state) do
    apply(m, f, [state])
  end

  defp run_function(module, state) when is_atom(module) do
    apply(module, :run, [state])
  end

  defp run_function(fun, state) when is_function(fun) do
    fun.(state)
  end

  defp now_ms() do
    :erlang.monotonic_time(:millisecond)
  end
end
