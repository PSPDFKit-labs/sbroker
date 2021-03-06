%%-------------------------------------------------------------------
%%
%% Copyright (c) 2015, James Fish <james@fishcakez.com>
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License. You may obtain
%% a copy of the License at
%%
%% http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied. See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%%-------------------------------------------------------------------
-module(sbroker_statem_statem).

-include_lib("proper/include/proper.hrl").

-export([quickcheck/0]).
-export([quickcheck/1]).
-export([check/1]).
-export([check/2]).

-export([module/0]).
-export([args/0]).
-export([init/1]).
-export([handle_timeout/3]).
-export([handle_out/3]).
-export([handle_out_r/3]).
-export([config_change/3]).

-export([initial_state/0]).
-export([command/1]).
-export([precondition/2]).
-export([next_state/3]).
-export([postcondition/3]).

quickcheck() ->
    quickcheck([]).

quickcheck(Opts) ->
    proper:quickcheck(prop_sbroker_queue(), Opts).

check(CounterExample) ->
    check(CounterExample, []).

check(CounterExample, Opts) ->
    proper:check(prop_sbroker_queue(), CounterExample, Opts).

prop_sbroker_queue() ->
    ?FORALL(Cmds, commands(?MODULE),
            ?TRAPEXIT(begin
                          {History, State, Result} = run_commands(?MODULE, Cmds),
                          ok,
                          ?WHENFAIL(begin
                                        io:format("History~n~p", [History]),
                                        io:format("State~n~p", [State]),
                                        io:format("Result~n~p", [Result])
                                    end,
                                    aggregate(command_names(Cmds), Result =:= ok))
                      end)).

module() ->
    sbroker_statem_queue.

args() ->
    {oneof([out, out_r]), resize(4, list(oneof([0, choose(1, 2)])))}.

init({Out, Drops}) ->
    {Out, drop, infinity, {Drops, Drops}}.

handle_timeout(_, _, {[], []} = State) ->
    {0, State};
handle_timeout(_, [], State) ->
    {0, State};
handle_timeout(Time, L, {[], Config}) ->
    handle_timeout(Time, L, {Config, Config});
handle_timeout(_, L, {[Drop | Drops], Config}) ->
    {min(Drop, length(L)), {Drops, Config}}.

handle_out(Time, L, State) ->
    handle_timeout(Time, L, State).

handle_out_r(Time, L, State) ->
    handle_timeout(Time, L, State).

config_change(_, {Out, Config}, {_, Config} = State) ->
    {Out, drop, infinity, State};
config_change(_, {Out, Drops}, _) ->
    {Out, drop, infinity, {Drops, Drops}}.

initial_state() ->
    sbroker_queue_statem:initial_state(?MODULE).

command(State) ->
    sbroker_queue_statem:command(State).

precondition(State, Call) ->
    sbroker_queue_statem:precondition(State, Call).

next_state(State, Value, Call) ->
    sbroker_queue_statem:next_state(State, Value, Call).

postcondition(State, Call, Result) ->
    sbroker_queue_statem:postcondition(State, Call, Result).
