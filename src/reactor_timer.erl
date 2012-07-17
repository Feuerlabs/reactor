%%%---- BEGIN COPYRIGHT -------------------------------------------------------
%%%
%%% Copyright (C) 2012 Feuerlabs, Inc. All rights reserved.
%%%
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at http://mozilla.org/MPL/2.0/.
%%%
%%%---- END COPYRIGHT ---------------------------------------------------------
%%% @author Tony Rogvall <tony@rogvall.se>
%%% @doc
%%%    Reactor module for timer
%%% @end
%%% Created :  8 Dec 2011 by Tony Rogvall <tony@rogvall.se>

-module(reactor_timer).

-behaviour(reactor).
-export([fields/0, handlers/0]).
-export([create/2, create/3]).

%% misc
-export([test/0]).

fields() ->
    [
     {tick,false},        %% set when time is up
     {cycle, false},      %% end of one duration
     {ticks_per_sec,10},  %% granularity (max 1000)
     {time,0.0},          %% 0.0 -> 1.0
     {running,false},     %% set while timer is running
     {ref,undefined},     %% ref of the timer
     {activate,false},    %% activation signal to start
     {loop,false},        %% restart when done
     {duration,0}         %% timer duration in ms
    ].

handlers() ->
    [
     {timer_tick_handler, 
      10, ref, [tick,ref],
      fun(true,Ref) ->
	      case erlang:read_timer(Ref) of
		  false ->
		      reactor:signal(cycle, true),
		      case reactor:value(loop) of
			  true ->
			      start(reactor:value(duration));
			  false ->
			      reactor:signal(time, 1.0),
			      undefined
		      end;
		  Remain ->
		      tick(Remain,Ref)
	      end;
	 (false,Ref) ->
	      Ref
      end},
       
     {timer_activate_handler,
      20, ref,
      [activate,running,duration],
      fun(true,false,Time) ->
	      start(Time);
	 (true,true,_Time) ->
	      reactor:value(ref);
	 (false,_,_Time) ->
	      case reactor:value(ref) of
		  undefined ->
		      undefined;
		  Ref ->
		      erlang:cancel_timer(Ref)
	      end
      end}
    ].
 
%%--------------------------------------------------------------------
%% @doc
%%    Create a reactor timer.
%%    The dynamic fields of a timer consists of:
%%    <pre>
%%        tick     :: boolean()
%%        cycle    :: boolean()
%%        ticks_per_sec :: pos_integer()
%%        time     :: float() 
%%        running  :: boolean()
%%        ref      :: reference()
%%        activate :: boolean()
%%        loop     :: boolean()
%%        duration :: non_neg_integer()
%%    </pre>
%% @end
%%--------------------------------------------------------------------
-spec create(Name::atom(), Duration::non_neg_integer()) -> pid().

create(Name, Duration) ->
    reactor:create([?MODULE], [{'@name',Name},{duration,Duration}]).

create(Name, Duration, Options) ->
    reactor:create([?MODULE], [{'@name',Name},{duration,Duration}|Options]).
    

tick(Remain,Ref) ->
    start_tick(),
    Duration = reactor:value(duration),
    reactor:signal(time, (Duration - Remain) / Duration),
    Ref.
    
start(Duration) ->
    start_tick(),
    reactor:signal_after(Duration, cycle, true).

start_tick() ->
    TicksPerSec = reactor:value(ticks_per_sec),
    TickTime = 1000 div TicksPerSec,
    reactor:signal_after(TickTime, tick, true).

test() ->
    T1 = create(t1, 2000),
    T2 = create(t2, 3000),
    Out = reactor_format:create(out, "time = ~w\n"),
    reactor:connect(T1,time,Out,input),
    reactor:connect(T2,time,Out,input),
    reactor:signal(T1,activate,true),
    reactor:signal(T2,activate,true),
    ok.


    
