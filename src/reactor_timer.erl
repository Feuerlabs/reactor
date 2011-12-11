%%% @author Tony Rogvall <tony@rogvall.se>
%%% @copyright (C) 2011, Tony Rogvall
%%% @doc
%%%    Reactor module for timer
%%% @end
%%% Created :  8 Dec 2011 by Tony Rogvall <tony@rogvall.se>

-module(reactor_timer).

-export([create/2]).
-export([test/0]).

create(ID,Duration) ->
    reactor:create(
      ID,
      [
       {tick,false},        %% set when time is up
       {cycle, false},      %% end of one duration
       {ticks_per_sec,10},  %% granularity (max 1000)
       {time,0.0},          %% 0.0 -> 1.0
       {running,false},     %% set while timer is running
       {ref,undefined},     %% ref of the timer
       {activate,false},    %% activation signal to start
       {loop,false},        %% restart when done
       {duration,Duration}  %% timer duration in ms
      ],

      [{timer_tick_handler, 
	10, ref, [tick,ref],
	fun(true,Ref) ->
		case erlang:read_timer(Ref) of
		    false ->
			reactor:set(cycle, true),
			case reactor:value(loop) of
			    true ->
				start(reactor:value(duration));
			    false ->
				reactor:set(time, 1.0),
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
      ]).

tick(Remain,Ref) ->
    start_tick(),
    Duration = reactor:value(duration),
    reactor:set(time, (Duration - Remain) / Duration),
    Ref.
    
start(Duration) ->
    start_tick(),
    reactor:set_after(Duration, cycle, true).

start_tick() ->
    TicksPerSec = reactor:value(ticks_per_sec),
    TickTime = 1000 div TicksPerSec,
    reactor:set_after(TickTime, tick, true).

test() ->
    T1 = create(t1, 2000),
    T2 = create(t2, 3000),
    Out = reactor_format:create(out, "time = ~w\n"),
    reactor:connect(T1,time,Out,input),
    reactor:connect(T2,time,Out,input),
    reactor:set(T1,activate,true),
    reactor:set(T2,activate,true),
    ok.


    
