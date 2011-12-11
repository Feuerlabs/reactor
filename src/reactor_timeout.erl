%%% @author Tony Rogvall <tony@rogvall.se>
%%% @copyright (C) 2011, Tony Rogvall
%%% @doc
%%%    Reactor module for timeout handling
%%% @end
%%% Created :  8 Dec 2011 by Tony Rogvall <tony@rogvall.se>

-module(reactor_timeout).

-export([create/2]).
-export([test/0]).

create(ID,Duration) ->
    reactor:create(
      ID,
      [
       {timedout,false},    %% set when time is up
       {running,false},     %% set while timer is running
       {ref,undefined},     %% ref of the timer
       {activate,false},    %% activation signal to start
       {duration,Duration}  %% timer duration
      ],

      [
       {timeout_active_handler,
	10, ref, 
	[activate,running,duration,ref],
	fun(true,false,Time,_Ref) ->
		reactor:set_after(Time, timedout, true);
	   (true,true,_Time,Ref) ->			     
		Ref;
	   (false,true,_Time,Ref) ->
		erlang:cancel_timer(Ref),
		undefined;
	   (false,_,_Time,_Ref) ->
		undefined
	end}
      ]).

test() ->
    T1 = create(t1, 2000),
    T2 = create(t2, 3000),
    Out = reactor_format:create(out, "timedout = ~w\n"),
    reactor:connect(T1,timedout,Out,input),
    reactor:connect(T2,timedout,Out,input),
    reactor:connect(T1,timedout,T2,activate),
    reactor:set(T1,activate,true),
    ok.