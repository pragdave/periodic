defmodule Periodic do
  use DynamicSupervisor

  @moduledoc """
  See `Periodic.repeat/3` for information
  """

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end


  @doc """
  Create a process that will run a function every `n` milliseconds.

  The funcion to be run can be passed as

  * an anonymous function of arity 1,
  * a module conntaining a `run/1` function
  * a `{module, function_name}` tuple that designates a zero-arity function.

  THe function will be passed a state, and may return:

  * `{ :ok, updated_state }`, in which case it will be scheduled to run again
    after an interval with that new state.

  * `{ :change_interval, new_interval, updated_state }` which will change the
    reschedule interval to `new_interval`ms.

  * `{ :stop, reason }`, in which case the function will not be rescheduled. You
    probably want to use `:normal` for the reason.


  """
  @spec repeat(atom() | tuple() | ( (term(), integer())-> term()), integer(), keyword()) :: { :ok, pid } | { :error, term() }

  def repeat(task_spec, interval, options \\ [])
  when (is_tuple(task_spec) or is_atom(task_spec) or is_function(task_spec))
   and is_integer(interval) and is_list(options)

   do
    DynamicSupervisor.start_child(__MODULE__, { Periodic.Runner, { task_spec, interval, options }})
  end


  @doc """
  Terminate a periodic task. Pass this either the name or the pid of the task to
  be terminated,
  """

  def stop_task(name) do
    DynamicSupervisor.terminate_child(__MODULE__, name)
  end
end
