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
%% @doc Implements a basic queue management algorithm where items are dropped
%% once their sojourn time is greater than a timeout value.
%%
%% `squeue_timeout' can be used as the active queue management module in a
%% `squeue' queue. It's argument is a `non_neg_integer()', which is the timeout
%% value, i.e. the minimum sojourn time at which items are dropped from the
%% queue.
-module(squeue_timeout).

-behaviour(squeue).

-export([init/1]).
-export([handle_timeout/3]).
-export([handle_out/3]).
-export([handle_out_r/3]).
-export([handle_join/3]).

-record(state, {timeout :: non_neg_integer(),
                timeout_next = 0 :: non_neg_integer()}).

%% @private
-spec init(Timeout) -> State when
      Timeout ::non_neg_integer(),
      State :: #state{}.
init(Timeout) when is_integer(Timeout) andalso Timeout >= 0 ->
    #state{timeout=Timeout}.

%% @private
-ifdef(LEGACY_TYPES).
-spec handle_timeout(Time, Q, State) -> {Drops, NQ, NState} when
      Time :: non_neg_integer(),
      Q :: queue(),
      State :: #state{},
      Drops :: [{DropSojournTime :: non_neg_integer(), Item :: any()}],
      NQ :: queue(),
      NState :: #state{}.
-else.
-spec handle_timeout(Time, Q, State) -> {Drops, NQ, NState} when
      Time :: non_neg_integer(),
      Q :: queue:queue(Item),
      State :: #state{},
      Drops :: [{DropSojournTime :: non_neg_integer(), Item :: any()}],
      NQ :: queue:queue(Item),
      NState :: #state{}.
-endif.
handle_timeout(Time, Q, #state{timeout_next=TimeoutNext} = State)
  when Time < TimeoutNext ->
    {[], Q, State};
handle_timeout(Time, Q, #state{timeout=Timeout} = State) ->
    timeout(queue:peek(Q), Time - Timeout, Time, Q, State, []).

%% @private
-ifdef(LEGACY_TYPES).
-spec handle_out(Time, Q, State) -> {Drops, NQ, NState} when
      Time :: non_neg_integer(),
      Q :: queue(),
      State :: #state{},
      Drops :: [{DropSojournTime :: non_neg_integer(), Item :: any()}],
      NQ :: queue(),
      NState :: #state{}.
-else.
-spec handle_out(Time, Q, State) -> {Drops, NQ, NState} when
      Time :: non_neg_integer(),
      Q :: queue:queue(Item),
      State :: #state{},
      Drops :: [{DropSojournTime :: non_neg_integer(), Item :: any()}],
      NQ :: queue:queue(Item),
      NState :: #state{}.
-endif.
handle_out(Time, Q, State) ->
    handle_timeout(Time, Q, State).

%% @private
-ifdef(LEGACY_TYPES).
-spec handle_out_r(Time, Q, State) -> {Drops, NQ, NState} when
      Time :: non_neg_integer(),
      Q :: queue(),
      State :: #state{},
      Drops :: [{DropSojournTime :: non_neg_integer(), Item :: any()}],
      NQ :: queue(),
      NState :: #state{}.
-else.
-spec handle_out_r(Time, Q, State) -> {Drops, NQ, NState} when
      Time :: non_neg_integer(),
      Q :: queue:queue(Item),
      State :: #state{},
      Drops :: [{DropSojournTime :: non_neg_integer(), Item :: any()}],
      NQ :: queue:queue(Item),
      NState :: #state{}.
-endif.
handle_out_r(Time, Q, State) ->
    handle_timeout(Time, Q, State).

%% @private
-ifdef(LEGACY_TYPES).
-spec handle_join(Time, Q, State) -> {[], Q, NState} when
      Time :: non_neg_integer(),
      Q :: queue(),
      State :: #state{},
      NState :: #state{}.
-else.
-spec handle_join(Time, Q, State) -> {[], Q, NState} when
      Time :: non_neg_integer(),
      Q :: queue:queue(),
      State :: #state{},
      NState :: #state{}.
-endif.
handle_join(_Time, Q, State) ->
    case queue:is_empty(Q) of
        true ->
            {[], Q, State#state{timeout_next=0}};
        false ->
            {[], Q, State}
    end.

%% Internal

timeout(empty, _MinStart, _Time, Q, State, Drops) ->
    %% The tail_time of the squeue is unknown (an item could be added in the
    %% past), so can not set a timeout_next.
    {Drops, Q, State};
timeout({value, {Start, _}}, MinStart, _Time, Q,
        #state{timeout=Timeout} = State, Drops) when Start > MinStart ->
    %% Item is below sojourn timeout, it is the first item that can be
    %% dropped and it can't be dropped until it is above sojourn timeout.
    {Drops, Q, State#state{timeout_next=Start+Timeout}};
timeout({value, Item}, MinStart, Time, Q, State, Drops) ->
    %% Item is above sojourn timeout so drop it.
    NQ = queue:drop(Q),
    timeout(queue:peek(NQ), MinStart, Time, NQ, State, [Item | Drops]).
