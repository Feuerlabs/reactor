%%% @author Tony Rogvall <tony@rogvall.se>
%%% @copyright (C) 2011, Tony Rogvall
%%% @doc
%%%    reactor front api
%%% @end
%%% Created :  8 Dec 2011 by Tony Rogvall <tony@rogvall.se>

-module(reactor).

-export([create/3, create_link/3, create_opt/4]).
-export([set/2,set/3]).
-export([set_after/3, set_after/4]).
-export([connect/2,connect/3,connect/4]).
-export([disconnect/2,disconnect/3,disconnect/4]).
-export([assign/2]).
-export([add_handler/5, add_handler/6, del_handler/2]).
-export([add_field/2, del_field/2]).
-export([add_child/1, add_child/2]).
-export([del_child/1, del_child/2]).

-export([id/0, value/1]).
-export([parent/0, children/0]).


-define(assert_reactor(Func,Arity),
	case reactor_core:is_reactor() of
	    false ->
		io:format("reactor_core: execution of ~s/~w:~w in none reactor",
			  [Func,Arity,?LINE]),
		exit(noreactor);
	    true ->
		true
	end).


create(ID, FieldValues, Handlers) ->
    do_create_opt(ID, FieldValues, Handlers, []).

create_link(ID, FieldValues, Handlers) ->
    do_create_opt(ID, FieldValues, Handlers, [link]).

create_opt(ID, FieldValues, Handlers, Opts) ->
    do_create_opt(ID, FieldValues, Handlers, Opts).    

do_create_opt(ID, FieldValues, Handlers, Opts) ->
    spawn_opt(fun() ->
		  reactor_core:enter_loop(ID, FieldValues, Handlers)
	      end, Opts).

signal_(Field, Value) ->
    case reactor_core:current_handler() of
	undefined ->
	    {reactor_signal,undefined,undefined,Field,Value};
	Handler ->
	    {reactor_signal,self(),Handler,Field,Value}
    end.

set(Pid, Field, Value)  
  when is_pid(Pid), is_atom(Field) ->
    Pid ! signal_(Field, Value).

set_after(Time, Pid, Field, Value) 
  when is_integer(Time), Time > 0, is_pid(Pid), is_atom(Field) ->
    erlang:send_after(Time, Pid, signal_(Field,Value)).

set_after(Time, Field, Value) ->
    ?assert_reactor(set_after,3),
    set_after(Time, self(), Field, Value).

set(Field, Value) ->
    ?assert_reactor(set,2),
    %% fixme, implement a more direct version, updating changed to next loop.
    %% avoid sending message !
    set(self(), Field, Value).

%% Connect output from Src:SrcKey to Dst:DstKey
connect(Src,SrcField,Dst,DstField) when is_atom(SrcField),is_atom(DstField) ->
    set(Src,'@connect',{SrcField,Dst,DstField}).

connect(SrcField,Dst,DstField) when is_atom(SrcField),is_atom(DstField) ->
    ?assert_reactor(connect,3),
    set(self(),'@connect',{SrcField,Dst,DstField}).

connect(Dst,Field) when is_atom(Field) ->
    ?assert_reactor(connect,2),
    set(self(),'@connect',{Field,Dst,Field}).

%% Disconnect output from Src:SrcKey to Dst:DstKey
disconnect(Src,SrcField,Dst,DstField) when
      is_pid(Src), is_atom(SrcField), is_pid(Dst), is_atom(DstField) ->
    set(Src,'@disconnect',{SrcField,Dst,DstField}).

disconnect(SrcField,Dst,DstField) when
      is_atom(SrcField), is_pid(Dst), is_atom(DstField) ->
    ?assert_reactor(disconnet,3),
    set(self(),'@disconnect',{SrcField,Dst,DstField}).

disconnect(Dst,Field) when
      is_pid(Dst), is_atom(Field) ->
    ?assert_reactor(disconnet,2),
    set(self(),'@disconnect',{Field,Dst,Field}).

add_handler(Pid,Prio,OFs,IFs,Body) when 
      is_pid(Pid), is_list(IFs), is_function(Body) ->
    ID = make_ref(),
    H = {ID,Prio,OFs,IFs,Body},
    set(Pid, '@add_handler', H),
    ID.

add_handler(Pid,ID,Prio,OFs,IFs,Body) when 
      is_pid(Pid), is_list(IFs), is_function(Body) ->
    H = {ID,Prio,OFs,IFs,Body},
    set(Pid, '@add_handler', H),
    ID.

del_handler(Pid,ID) when is_pid(Pid) ->
    set(Pid, '@del_handler', ID).

add_field(Pid, Fv={Field,_Value}) when is_pid(Pid), is_atom(Field) ->
    set(Pid, '@add_field', Fv);
add_field(Pid, Field) when is_pid(Pid), is_atom(Field) ->
    set(Pid, '@add_field', Field).

del_field(Pid, Field) when is_pid(Pid), is_atom(Field) ->
    set(Pid, '@del_field', Field).

add_child(Pid, Child) when is_pid(Pid), is_pid(Child) ->
    connect(Pid, '@child', Child, '@parent').

add_child(Child) when is_pid(Child) ->
    ?assert_reactor(add_child,1),
    connect(self(), '@child', Child, '@parent').

del_child(Pid, Child) when is_pid(Pid), is_pid(Child) ->
    disconnect(Pid, '@child', Child, '@parent').

del_child(Child) when is_pid(Child) ->
    ?assert_reactor(add_child,1),
    disconnect(self(), '@child', Child, '@parent').

%%--------------------------------------------------------------------
%% @doc check if caller is executing in a reactor.
%% @spec 
%% @end
%%--------------------------------------------------------------------

%% internal reactor function
value(Field) ->
    ?assert_reactor(value,1),
    reactor_core:get_value(Field).

id() ->
    ?assert_reactor(id,0),
    reactor_core:get_value('@id').

parent() ->
    ?assert_reactor(parent,0),
    reactor_core:get_value('@parent').

children() ->
    ?assert_reactor(children,0),
    reactor_core:reactors_channel('@child').

%% raw assignment no trigger nor propagation
assign(Field,Value) ->
    ?assert_reactor(assign,2),
    reactor_core:assign_value(Field,Value).

