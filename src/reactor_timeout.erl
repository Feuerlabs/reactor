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
%%%    Reactor module for timeout handling
%%% @end
%%% Created :  8 Dec 2011 by Tony Rogvall <tony@rogvall.se>

-module(reactor_timeout).

-behaviour(reactor).
-export([fields/0, handlers/0]).
-export([create/2]).

%% misc
-export([test/0]).

fields() ->
    [
     {timedout,false},    %% set when time is up
     {running,false},     %% set while timer is running
     {ref,undefined},     %% ref of the timer
     {activate,false},    %% activation signal to start
     {duration,0}         %% timer duration
    ].

handlers() ->    
    [
     {timeout_active_handler,
      10, ref, 
      [activate,running,duration,ref],
      fun(true,false,Time,_Ref) ->
	      reactor:signal_after(Time, timedout, true);
	 (true,true,_Time,Ref) ->			     
	      Ref;
	 (false,true,_Time,Ref) ->
	      erlang:cancel_timer(Ref),
	      undefined;
	 (false,_,_Time,_Ref) ->
	      undefined
      end}
    ].
    

%% @doc
%%    Create a timeout reactor
%%    The dynamic fields of a timer consists of:
%%    <pre>
%%        timeout    :: boolean()
%%        running    :: boolean()
%%        ref        :: undefined | reference()
%%        activate   :: boolean()
%%        duration   :: timeout()
%%    </pre>
%%
%% @end
-spec create(ID::atom(), Duration::non_neg_integer()) -> pid().

create(Name, Duration) ->
    reactor:create([?MODULE],[{'@name',Name},{duration,Duration}]).

test() ->
    T1 = create(t1, 2000),
    T2 = create(t2, 3000),
    Out = reactor_format:create(out, "timedout = ~w\n"),
    reactor:connect(T1,timedout,Out,input),
    reactor:connect(T2,timedout,Out,input),
    reactor:connect(T1,timedout,T2,activate),
    reactor:signal(T1,activate,true),
    ok.
