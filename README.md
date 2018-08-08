<img align="right" width="200" title="logo: a clocks"
src="./assets/images/clock.svg">

# Periodic: run functions at intervals [![Build Status](https://travis-ci.org/pragdave/periodic.svg?branch=master)](https://travis-ci.org/pragdave/periodic)


The Periodic supervisor manages a dynamic set of tasks. Each of these
tasks is run repeatedly at a per-task specified interval.

A task is repreented as a function. It receives a single parameter, its
current state. When complete, this function can return

* `{ :ok, new_state }` to have itself rescheduled with a (potentially)
  updated state.

* `{ :change_interval, new_interval, new_state }` to reschedule itself
  with a new state, but updating the interval betweeen schedules.

* `{ :stop, :normal }` to exit gracefully.

* any other return value will be treated as an error.\

All intervals are specified in milliseconds.

## What does it look like?

mix.exs:

~~~ elixir
deps: { :periodic, ">= 0.0.0" },
~~~

application.ex

~~~ elixir
child_spec = [
  Periodic,
  . . .
]
~~~

This module is a genserver that fetches data from two feeds. The first
is fetched every 30 seconds, and the second every 60s.

~~~ elixir
defmodule Fetcher do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_) do
    { :ok, _ } = Periodic.repeat({ __MODULE__, :fetch }, 30_000,
                                 state: %{ feed: Stocks, respond_to: self() })

    { :ok, _ } = Periodic.repeat({ __MODULE__, :fetch }, 60_000,
                                 state: %{ feed: Bonds, respond_to: self() }, offset: 15_000)
    { :ok, %{} }
  end

  # this function is run by the two task runners created in `init/1)`. They
  # fetch data from the feed whose name is in the state, and then send the
  # result back to the original server

  def fetch(task) do
    data = task.feed.fetch()
    Fetcher.handle_data(task.respond_to, task.feed, data)
    { :ok, state }
  end

  # and this function forwards the feed response on to the server
  def handle_data(worker_pid, feed, data) do
    GenServer.cast(worker_pid, { incoming, feed, data })
  end

  def handle_cast({ :incoming, Stocks, data }, state) do
    ## ...
  end

  def handle_cast({ :incoming, Bonds, data }, state) do
    ## ...
  end
end
~~~

Notes:

* In the real world you'd likely split this into multiple modules.

* The parameters to the first call to `Periodic.repeat` say run
  `Fetcher.fetch` every 30s, passing it a map containing the name
   of a feed and the pid to send the data to.

* the second call to `Fetcher.fetch` sets up a second schedule. This
  happens to call the same function, but every 60s. It also offsets
  the time of these calls (starting with the first) by 15s

  This means the timeline for calls to the function will be:

  | time from start | call                          |
  |-----------------|-------------------------------|
  |   +0s           | fetch{feed: Stocks, ...}      |
  |   +15s          | fetch{feed: Bonds,  ...}      |
  |   +30s          | fetch{feed: Stocks, ...}      |
  |   +60s          | fetch{feed: Stocks, ...}      |
  |   +75s          | fetch{feed: Bonds,  ...}      |
  |   +90s          | fetch{feed: Stocks, ...}      |
  |   +120s         | fetch{feed: Stocks, ...}      |
  |   +135s         | fetch{feed: Bonds,  ...}      |
  |    . . .        |                               |

* The `fetch` function gets data for the appropriate feed, and then
  calls back into the original module, passing the pid of the genserver,
  the name of the feed and the data.

* The `handle_data` function it calls just forwards the request on to
  the genserver.

  (Technically the call to `GenServer.cast` could have been made
  directly in the `fetch` function, but in our mythical _real world_,
  it's likely the periodically run functions would be decoupled from the
  genserver.

### The API

To cause a function to be invoked repeatedly every so many milliseconds,
use:

~~~ elixir
{ :ok, pid } = Periodic.repeat(func_spec, interval, options \\ [])
~~~

* `func_spec` may be an anonymous function of arity 1, a 2-tuple
  containing the name of a module and the name of a function, or just
  the name of the module (in which case the function is assumed to be
  named `run/1`.

* The `interval` specifies the number of milliseconds between executions
  of the function. `Periodic` makes some attempt to minimize drift of
  this timing, but you should treat the value as approximate: you'll see
  some spreading of the interval timing of perhaps a millisecond on some
  iterations.

* The options list make contain:

  * `state: ` _term_

    The initial state that is passed as a parameter when the function is
    first executeded.

  * `name:` _name_

    A name for the task. This can be used subsequently to terminate it.

  * `offset:` _ms_

    An offset (in milliseconds) to be applied before the first execution
    of the function. This can be used to stagger executions of multiple
    sets of periodic functions if their intervals would otherwise cause
    them to execute at the same time.

You can remove a previously added periodic function with

~~~ elixir
Periodic.stop_task(pid)
~~~

where `pid` is the value returned by `repeat/3`


### The Callback Function

You write functions that `Periodic` will call. These will have the spec:

~~~ elixir
@typep state :: term()
@typep periodic_callback_return ::
    { :ok, state() }                                       |
    { :change_interval, new_interval::integer(), state() } |
    { :stop, :normal }                                     |
    other :: any()

@spec periodic_callback(state :: state()) :: periodic_callback_return()
~~~

### Runtime Charactertics

* `Periodic` is a `DynamicSupervisor` which should be started by one of
  your application's own supervisors.

* Each call to `Periodic.repeat` creates a new worker process. This
  worker spends most of its time waiting for the interval timer to
  trigger, at which point it invokes the function you passed it, then
  resets the timer.

* If a function takes more time to execute than the interval time, then
  the next call to that function will happen immediately, and all
  subsequent calls to it will be timeshifted by the overrun.


> See [license.md](license.md) for copyright and licensing information.