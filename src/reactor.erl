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
%%%    reactor front api
%%% @end
%%% Created :  8 Dec 2011 by Tony Rogvall <tony@rogvall.se>

-module(reactor).

-export([create/2, create_link/2, create_opt/3]).
-export([signal/2,signal/3]).
-export([signal_after/3, signal_after/4]).
-export([connect/2,connect/3,connect/4]).
-export([disconnect/2,disconnect/3,disconnect/4]).
-export([set/2]).
-export([add_handler/6, del_handler/2]).
-export([add_field/2, del_field/2]).
-export([add_child/1, add_child/2]).
-export([del_child/1, del_child/2]).

-export([type/0, value/1]).
-export([parent/0, children/0]).

-export([behaviour_info/1]).

-define(assert_reactor(Func,Arity),
	case reactor_core:is_reactor() of
	    false ->
		io:format("reactor_core: execution of ~s/~w:~w in none reactor",
			  [Func,Arity,?LINE]),
		exit(noreactor);
	    true ->
		true
	end).

-type void() :: 'ok'.
-type reactor() :: pid().
-type handler_id() :: term().
-type handler_prio() :: term().
-type field_name() :: atom().
-type field_decl() :: field_name() | {field_name(), term()}.
-type handler() :: {Hid::handler_id(),Prio::handler_prio(),
		    OFs::'void' | field_name() | [field_name()],
		    IFs::[field_name()], Body::fun()}.
-type prio_level() :: 'low' | 'normal' | 'high'.
-type create_option() :: 'link'
		       | 'monitor'
		       | {'priority', prio_level()}
		       | {'fullsweep_after', Number::non_neg_integer()}
		       | {'min_heap_size',  non_neg_integer()}
		       | {'min_bin_vheap_size', non_neg_integer()}.

%% The gui component behaviour
behaviour_info(callbacks) ->
    [
     {fields,   0},
     {handlers, 0},
     {create,   2}
    ];
behaviour_info(_) ->
    undefined.

%%--------------------------------------------------------------------
%% @doc
%%    Create a reactor process. Install initial fields and handlers.
%%    Standard field:
%%    <pre>
%%       '@type'       :: atom()
%%       '@exit'       :: boolean()
%%       '@auto_exit'  :: boolean()
%%       '@dump'       :: boolean()
%%       '@child'      :: pid()
%%       '@parent'     :: pid()
%%       '@init'       :: any()
%%       '@terminate'  :: any()
%%       '@add_field'  :: field_decl()
%%       '@del_field'  :: atom()
%%       '@connect'    :: {atom(),pid(),atom()}
%%       '@disconnect' :: {atom(),pid(),atom()}
%%       '@add_handler':: handler()
%%       '@del_handler':: handler_id()
%%       '@event'      :: term()
%%       '@error_handler' :: {reason(),pid(),atom()} | reason()
%%    </pre>
%%
%% @end
%%--------------------------------------------------------------------
-spec create(IDs::[atom()],Args::[{field_name(),term()}]) ->  reactor().

create(IDs, Args) ->
    do_create_opt_(IDs, Args, []).

%%--------------------------------------------------------------------
%% @doc
%%    Create and link a reactor process. Install initial fields and handlers.
%% @end
%%--------------------------------------------------------------------
-spec create_link(IDs::[atom()],Args::[{field_name(),term()}]) ->  reactor().

create_link(IDs, Args) ->
    do_create_opt_(IDs, Args, [link]).

%%--------------------------------------------------------------------
%% @doc
%%    Create a reactor process with spawn options. The spawn options are
%%    the same as for erlang::spawn_opt.
%% @end
%%--------------------------------------------------------------------

-spec create_opt(IDs::[atom()],
		 Args::[{field_name(),term()}],
		 CreatOptions::[create_option()]) -> reactor().

create_opt(IDs, Args, Opts) ->
    do_create_opt_(IDs, Args, Opts).    

%% @hidden
%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------

do_create_opt_(IDs, Args, Opts) ->
    spawn_opt(fun() ->
		      reactor_core:enter_loop(IDs, Args)
	      end, Opts).

signal_(Field, Value) ->
    case reactor_core:current_handler() of
	undefined ->
	    {reactor_signal,undefined,undefined,Field,Value};
	Handler ->
	    {reactor_signal,self(),Handler,Field,Value}
    end.

%%--------------------------------------------------------------------
%% @doc
%%    Signal a reactor channel value.
%% @end
%%--------------------------------------------------------------------
-spec signal(Reactor::reactor(), Field::field_name(), Value::term) -> term().

signal(Pid, Field, Value)  
  when is_pid(Pid), is_atom(Field) ->
    Pid ! signal_(Field, Value),
    Value.

%%--------------------------------------------------------------------
%% @doc
%%    Delay the signal of a reactor channel value with Timeout milli seconds.
%% @end
%%--------------------------------------------------------------------

-spec signal_after(Timeout::pos_integer(), Reactor::reactor(), 
		Field::field_name(), Value::term()) -> term().

signal_after(Time, Reactor, Field, Value) 
  when is_integer(Time), Time > 0, is_pid(Reactor), is_atom(Field) ->
    erlang:send_after(Time, Reactor, signal_(Field,Value)).

%%--------------------------------------------------------------------
%% @doc
%%    Delay the signal of internal reactor field, exectured with a
%%    reactor handler.
%% @end
%%--------------------------------------------------------------------

-spec signal_after(Timeout::pos_integer(), Field::field_name(), Value::term()) -> term().

signal_after(Time, Field, Value) ->
    ?assert_reactor(signal_after,3),
    signal_after(Time, self(), Field, Value).

%%--------------------------------------------------------------------
%% @doc
%%    Set current reactor field value, next execution loop
%% @end
%%--------------------------------------------------------------------
-spec signal(Field::field_name(), Value::term) -> term().

signal(Field, Value) ->
    ?assert_reactor(signal,2),
    %% fixme, implement a more direct version, updating changed to next loop.
    %% avoid sending message !
    signal(self(), Field, Value).

%%--------------------------------------------------------------------
%% @doc
%%    Connect field SrcField in reactor Src to field DstField in reactor Dst.
%% @end
%%--------------------------------------------------------------------
-spec connect(Src::reactor(),SrcField::field_name(),Dst::reactor(),DstField::field_name()) -> void().

connect(Src,SrcField,Dst,DstField) when is_atom(SrcField),is_atom(DstField) ->
    signal(Src,'@connect',{SrcField,Dst,DstField}), 
    ok.

%%--------------------------------------------------------------------
%% @doc
%%    Connect SrcField in current reactor Src to field DstField in reactor Dst.
%% @end
%%--------------------------------------------------------------------
-spec connect(SrcField::field_name(),Dst::reactor(),DstField::field_name()) -> void().

connect(SrcField,Dst,DstField) when is_atom(SrcField),is_atom(DstField) ->
    ?assert_reactor(connect,3),
    signal(self(),'@connect',{SrcField,Dst,DstField}),
    ok.

%%--------------------------------------------------------------------
%% @doc
%%    Connect Field in current reactor to field Field in reactor Dst.
%% @end
%%--------------------------------------------------------------------
-spec connect(Dst::reactor(),DstField::field_name()) -> void().

connect(Dst,Field) 
  when is_pid(Dst), is_atom(Field) ->
    ?assert_reactor(connect,2),
    signal(self(),'@connect',{Field,Dst,Field}),
    ok.

%%--------------------------------------------------------------------
%% @doc
%%    Disconnect field SrcField in reactor Src from 
%%    field DstField in reactor Dst.
%% @end
%%--------------------------------------------------------------------
-spec disconnect(Src::reactor(),SrcField::field_name(),Dst::reactor(),DstField::field_name()) -> void().

disconnect(Src,SrcField,Dst,DstField) when
      is_pid(Src), is_atom(SrcField), is_pid(Dst), is_atom(DstField) ->
    signal(Src,'@disconnect',{SrcField,Dst,DstField}),
    ok.

%%--------------------------------------------------------------------
%% @doc
%%    Disconnect field SrcField from current reactor from
%%    field DstField in reactor Dst.
%% @end
%%--------------------------------------------------------------------
-spec disconnect(SrcField::field_name(),Dst::reactor(),DstField::field_name()) -> void().

disconnect(SrcField,Dst,DstField) when
      is_atom(SrcField), is_pid(Dst), is_atom(DstField) ->
    ?assert_reactor(disconnet,3),
    signal(self(),'@disconnect',{SrcField,Dst,DstField}),
    ok.

%%--------------------------------------------------------------------
%% @doc
%%    Disconnect field 'Field' from current reactor from
%%    field 'Field' in reactor Dst.
%% @end
%%--------------------------------------------------------------------
-spec disconnect(Dst::reactor(),Field::field_name()) -> void().

disconnect(Dst,Field) when
      is_pid(Dst), is_atom(Field) ->
    ?assert_reactor(disconnet,2),
    signal(self(),'@disconnect',{Field,Dst,Field}),
    ok.

%%--------------------------------------------------------------------
%% @doc
%%
%% @end
%%--------------------------------------------------------------------

-spec add_handler(Dst::reactor(),Hid::handler_id(),Prio::handler_prio(),
		  OFs::'void' | field_name() | [field_name()],
		  IFs::[field_name()], Body::fun()) -> void().

add_handler(Dst,Hid,Prio,OFs,IFs,Body) when 
      is_pid(Dst), is_list(IFs), is_function(Body) ->
    H = {Hid,Prio,OFs,IFs,Body},
    signal(Dst, '@add_handler', H),
    ok.

%%--------------------------------------------------------------------
%% @doc
%%
%% @end
%%--------------------------------------------------------------------

-spec del_handler(Dst::reactor(),Hid::handler_id()) -> void().

del_handler(Dst,Hid) when is_pid(Dst) ->
    signal(Dst, '@del_handler', Hid),
    ok.

%%--------------------------------------------------------------------
%% @doc
%%
%% @end
%%--------------------------------------------------------------------

-spec add_field(Dst::reactor(),Field::field_decl()) -> void().

add_field(Pid, Fv={Field,_Value}) when is_pid(Pid), is_atom(Field) ->
    signal(Pid, '@add_field', Fv),
    ok;
add_field(Pid, Field) when is_pid(Pid), is_atom(Field) ->
    signal(Pid, '@add_field', Field),
    ok.

%%--------------------------------------------------------------------
%% @doc
%%
%% @end
%%--------------------------------------------------------------------

-spec del_field(Dst::reactor(),Field::field_name()) -> void().

del_field(Pid, Field) when is_pid(Pid), is_atom(Field) ->
    signal(Pid, '@del_field', Field),
    ok.

%%--------------------------------------------------------------------
%% @doc
%%
%% @end
%%--------------------------------------------------------------------

add_child(Pid, Child) when is_pid(Pid), is_pid(Child) ->
    connect(Pid, '@child', Child, '@parent').

add_child(Child) when is_pid(Child) ->
    ?assert_reactor(add_child,1),
    connect(self(), '@child', Child, '@parent').

%%--------------------------------------------------------------------
%% @doc
%%
%% @end
%%--------------------------------------------------------------------

del_child(Pid, Child) when is_pid(Pid), is_pid(Child) ->
    disconnect(Pid, '@child', Child, '@parent').

del_child(Child) when is_pid(Child) ->
    ?assert_reactor(add_child,1),
    disconnect(self(), '@child', Child, '@parent').

%%--------------------------------------------------------------------
%% @doc 
%%    return reactor field value, may only be extuted from with in a handler.
%% @end
%%--------------------------------------------------------------------
-spec value(Field::field_name()) -> term().

value(Field) ->
    ?assert_reactor(value,1),
    reactor_core:get_value(Field).

%%--------------------------------------------------------------------
%% @doc 
%%    Return the name of the reactor.
%% @end
%%--------------------------------------------------------------------

-spec type() -> atom().

type() ->
    ?assert_reactor(type,0),
    reactor_core:get_value('@type').

%%--------------------------------------------------------------------
%% @doc
%%
%% @end
%%--------------------------------------------------------------------

parent() ->
    ?assert_reactor(parent,0),
    reactor_core:get_value('@parent').

%%--------------------------------------------------------------------
%% @doc
%%
%% @end
%%--------------------------------------------------------------------

children() ->
    ?assert_reactor(children,0),
    reactor_core:reactors_channel('@child').

%%--------------------------------------------------------------------
%% @doc
%%    Set current reactor fields current value.
%% @end
%%--------------------------------------------------------------------
-spec set(Field::atom(), Value::term) -> term().

set(Field,Value) ->
    ?assert_reactor(set,2),
    reactor_core:set_value(Field,Value).

