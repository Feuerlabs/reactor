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
%%%    Reactor core
%%% @end
%%% Created :  7 Dec 2011 by Tony Rogvall <tony@rogvall.se>

-module(reactor_core).

%%
%% dictionary usage:
%%   {value,   F}  => {Value,Queue}   - current value and input queue
%%   {channel, F}  => [{{Dst,G},Mon}] - output connections
%%   {handset, F}  => [{Prio,ID}]     - ordset of handlers where F is in IFs
%%   {mon, Ref}  => {F,G}             - destination monitor
%%   {handler, ID}  => Handler        - handler with unique id ID
%%
%% Handler = {ID,Prio,IFs,OFs,Body}
%%

-export([enter_loop/2]).
-export([fields/0, handlers/0]).

-export([get_value/1, set_value/2]).
-export([is_reactor/0, current_handler/0]).
-export([reactors_channel/1]).

-import(lists, [map/2, foldl/3, foreach/2]).

-define(REACTOR_DICT,    '_REACTOR@DICT_').
-define(REACTOR_HANDLER, '_REACTOR@HANDLER_').

%% -define(debug, true).

-ifdef(debug).
-define(dbg(F,As), io:format((F),As)).
-else.
-define(dbg(F,As), ok).
-endif.

%% FIXME: import instead
%% -type void() :: 'ok'.
-type reactor() :: pid().
-type handler_id()   :: term().
-type handler_prio() :: term().
-type field_name()   :: atom().
-type field_decl() :: field_name() | {field_name(), term()}.
-type handler() :: {Hid::handler_id(),Prio::handler_prio(),
		    OFs::'void' | field_name() | [field_name()],
		    IFs::[field_name()], Body::fun()}.

-spec fields() -> [
		   {'@type',      atom()} |
		   {'@type_list', [atom()]} |
		   {'@name',      atom()} |
		   {'@exit',      boolean()} |
		   {'@auto_exit', boolean()} |
		   {'@dump',      boolean()} |
		   {'@child',     any()} |
		   {'@parent',    any()} |
		   {'@init',         any()} |   %% init handler
		   {'@terminate',    any()} |   %% termination handler
		   {'@add_field',    field_decl()} |
		   {'@del_field',    field_name()} |
		   {'@connect',      {field_name(),reactor(),field_name()}} |
		   {'@disconnect',   {field_name(),reactor(),field_name()}} |
		   {'@add_handler',  handler()} |
		   {'@del_handler',  handler_id()} |
		   {'@event',        any()} |
		   {'@error_handler',any()}].


fields() ->
    [
     {'@type',         undefined},
     {'@type_list',    []},
     {'@name',         undefined},
     {'@exit',         false},
     {'@auto_exit',    false},
     {'@dump',         false},
     {'@child',        undefined},
     {'@parent',       undefined},
     {'@init',         undefined},   %% init handler
     {'@terminate',    undefined},   %% termination handler
     {'@add_field',    undefined},
     {'@del_field',    undefiend},
     {'@connect',      undefined},
     {'@disconnect',   undefined},
     {'@add_handler',  undefined},
     {'@del_handler',  undefined},
     {'@event',        undefined},
     {'@error_handler',undefined}
    ].

-spec handlers() -> [handler()].
		       
handlers() ->
    [
     add_field_handler(),
     del_field_handler(),
     connect_handler(),
     disconnect_handler(),
     add_handler_handler(),
     del_handler_handler(),
     event_handler_handler(),
     exit_handler(),
     dump_handler()
    ].
    
%%--------------------------------------------------------------------
%% @doc
%%     Enter the reactor main loop
%% @end
%%--------------------------------------------------------------------
-spec enter_loop(Types::[atom()], Args::[{field_name(),term()}]) ->
			no_return.

enter_loop(Types, Args) ->
    D0 = dict:new(),
    %% insert all fields from module callbacks
    D1 = lists:foldl(
	   fun(Mod, Di) ->
		   add_fields_(Mod:fields(), Di)
	   end, D0, [?MODULE | Types]),
    %% and fields from arguments
    D2 = add_fields_(proplists:get_value(fields,Args,[]), D1),
    %% get main type 
    Type = case Types of
	       [] -> undefined;
	       [Type0] -> Type0;
	       _ -> lists:last(Types)
	   end,
    %% set all arguments
    D3 = lists:foldl(
	   fun({fields,_}, Di) -> Di;
	      ({handlers,_}, Di) -> Di;
	      ({Field,Value},Di) ->
		   set_value_(Field,Value,Di)
	   end, D2, [{'@type',Type},{'@type_list',Types}|Args]),
    %% insert all handlers
    D4 = lists:foldl(
	   fun(Mod, Di) ->
		   add_handlers_(Mod:handlers(), Di)
	   end, D3, [?MODULE | Types]),
    D5 = add_handlers_(proplists:get_value(handlers,Args,[]), D4),
    D6 = do_init(D5),
    loop(ordsets:new(), D6, infinity).

add_field_handler() ->
    %% @add_field :: atom() | {atom(),term()}
    {add_field_handler, 1, [], ['@add_field'],
     fun(FieldValue) -> add_field_(FieldValue) end}.

del_field_handler() ->
    %% @del_field :: atom()
    {del_field_handler, 1, [], ['@del_field'],
     fun(Field) -> del_field_(Field) end}.

add_handler_handler() ->
    %% @add_handler :: {term(),term(),atom()|[atom()],[atom()],function()}
    {add_handler_handler, 1, [], ['@add_handler'],
     fun(Handler) -> add_handler_(Handler) end}.

del_handler_handler() ->
    %% @del_handler :: term()
    {del_handler_handler, 1, [], ['@del_handler'],
     fun(ID) -> del_handler_(ID) end}.

connect_handler() ->
    %% @connect :: {atom(),pid(),atom()}
    {connect_handler, 1, [], ['@connect'],
     fun({Field,Dst,DstField}) -> connect_(Field,Dst,DstField) end}.

disconnect_handler() ->
    %% @disconnect :: {atom(),pid(),atom()}
    {disconnect_handler, 1, [], ['@disconnect'],
     fun({Field,Dst,DstField}) -> disconnect_(Field,Dst,DstField) end}.

event_handler_handler() ->
    %% @event :: term()
    {event_handler_handler, 1, [], ['@event'],
     fun(Event) -> 
	     io:format("reactor_core: got unhandled event ~p\n", [Event]),
	     Event
     end}.

exit_handler() ->
    %% @exit :: term
    {exit_handler, 1,[],['@exit'],
     fun(false) -> ok;
	(Reason) ->
	     do_terminate(get(?REACTOR_DICT)),
	     exit(Reason)
     end}.

dump_handler() ->
    %% @dump :: boolean()
    {dump_handler, 1,'@dump', ['@dump'],
     fun(true) ->
	     fields_dump_values(),false;
	(false) ->
	     false
     end}.

type(Dict) ->
    get_value_('@type', Dict).

%% Execute @init handler
do_init(IDict0) ->
    do_execute(IDict0, '@init').

%% Execte @terminate handler
do_terminate(IDict0) ->
    do_execute(IDict0, '@terminate').

do_execute(IDict0, XField) ->
    HSet = dict:fetch({handset,XField}, IDict0),
    Handlers = lists:map(fun({_Prio,ID}) ->
				 dict:fetch({handler,ID}, IDict0)
			 end, ordsets:to_list(HSet)),
    put(?REACTOR_DICT, IDict0),
    _Updated = execute_handlers(Handlers, ordsets:from_list([XField])),
    IDict1 = get(?REACTOR_DICT),
    IDict1.    

%%    
%% Main loop
%% loop(Changed, Fields, Reactors, Dict, Time, Wait) ->
%%
loop(Changed,Dict,Wait) ->
    receive
	{reactor_signal,_Src,_SrcField,Field,Value} ->
	    %% FIXME: do something nice with _Src and _SrcField,
	    %% like: if Field does not exist then report 
	    %% signal(_Src, '@error_handler', {enoent,self(),Field})
	    %% Value could be stored like: {Src,SrcField,Value} to be
	    %% able to trace where value came from...
	    %%
	    Dict1 = enq_value_(Field, Value, Dict),
	    Changed1 = ordsets:add_element(Field, Changed),
	    ?dbg("~p[~s]: input from (~w,~w), ~w = ~w\n", 
		 [self(),type(Dict),_Src,_SrcField,Field,Value]),
	    loop(Changed1,Dict1,0);
	
	{'DOWN',Ref,process,Dst,_Reason} ->
	    case dict:find({mon,Ref}, Dict) of
		error ->
		    loop(Changed,Dict,Wait);
		{ok,{F,G}} ->
		    ?dbg("~w[~s]: auto disconnect ~w:~w => ~w:~w (~p)\n",
			 [self(),type(Dict),self(),F,Dst,G,_Reason]),
		    List = list_channel_(F, Dict),
		    {_,Dict1} = del_from_channel_(F, {Dst,G}, List, Dict),
		    loop(Changed,Dict1,Wait)
	    end;

	Event ->
	    Dict1 = enq_value_('@event', Event, Dict),
	    Changed1 = ordsets:add_element('@event', Changed),
	    ?dbg("~p[~s]: event = ~p\n", [self(),type(Dict),Event]),
	    loop(Changed1,Dict1,0)
	    
    after Wait ->
	    {Changed1,Dict1} = handle_reaction(Changed,Dict),
	    case ordsets_is_empty(Changed1) of
		true ->
		    loop(Changed1,Dict1,infinity);
		false ->
		    loop(Changed1,Dict1,0)
	    end
    end.

current_handler() ->
    get(?REACTOR_HANDLER).

is_reactor() ->
    case get(?REACTOR_DICT) of
	undefined ->
	    false;
	_Dict -> 
	    true
    end.
    
%% Check if a field exist
is_field_(Field, Dict) ->
    case dict:find({value,Field},Dict) of
	error ->
	    false;
	{ok,_} ->
	    true
    end.

%% called from handler!
add_field_(FieldValue) ->
    Dict = add_field_(FieldValue, get(?REACTOR_DICT)),
    put(?REACTOR_DICT, Dict),
    ok.

add_fields_(Fs, Dict) ->
    lists:foldl(fun add_field_/2, Dict, Fs).

%% Add a field to the dictionary
add_field_({Field,Value}, Dict) ->
    add_field_(Field,Value,Dict);
add_field_(Field, Dict) ->
    add_field_(Field,undefined,Dict).

add_field_(Field, Default, Dict) ->
    case is_field_(Field, Dict) of
	false ->
	    Dict1 = init_value_(Field, Default, Dict),
	    Dict2 = init_channel_(Field, Dict1),
	    dict:store({handset, Field}, ordsets:new(), Dict2);
	true ->
	    io:format("warning: field ~p already defined\n", [Field]),
	    Dict
    end.
    
del_field_(Field) ->
    Dict = del_field_(Field, get(?REACTOR_DICT)),
    put(?REACTOR_DICT, Dict),
    ok.

del_field_(Field, Dict) ->
    case is_field_(Field, Dict) of
	false ->
	    io:format("warning: field ~p is not defined\n", [Field]),
	    Dict;
	true ->
	    lists:foreach(
	      fun({{_Dst,_G},Mon}) ->
		      %% fixme: send connection delete signal ?
		      erlang:demonitor(Mon,[flush])
	      end, list_channel_(Field, Dict)),
	    Dict1 = erase_value_(Field, Dict),
	    Dict2 = erase_channel_(Field, Dict1),
	    dict:erase({handset,Field}, Dict2)
    end.


add_handler_(Handler) ->
    Dict = add_handler_(Handler, get(?REACTOR_DICT)),
    put(?REACTOR_DICT, Dict),
    Dict.
	    
%% Add a list of reactors
add_handlers_([{Priority,OFs,IFs,Body}|Handlers],Dict) ->
    H = {make_ref(),Priority,OFs,IFs,Body},
    Dict1 = add_handler_(H,Dict),
    add_handlers_(Handlers, Dict1);
add_handlers_([{Priority,IFs,Body}|Handlers],Dict) ->
    H = {make_ref(),Priority,[],IFs,Body},
    Dict1 = add_handler_(H,Dict),
    add_handlers_(Handlers, Dict1);
add_handlers_([H|Handlers],Dict) ->
    Dict1 = add_handler_(H,Dict),
    add_handlers_(Handlers, Dict1);
add_handlers_([], Dict) ->
    Dict.

add_handler_(H={Hid,Prio,OFs,IFs,Body},Dict) ->
    ?dbg("add handler: ~w\n", [H]),
    case {fields_not_present(OFs,Dict),fields_not_present(IFs,Dict)} of
	{[],[]} ->
	    N = length(IFs),
	    if is_function(Body,N) ->
		    case dict:find({handler,Hid},Dict) of
			error ->
			    Dict1 = dict:store({handler,Hid},H,Dict),
			    add_field_handlers_(IFs,{Prio,Hid},Dict1);
			{ok,{Hid,Prio0,_OFs0,IFs0,_Body0}} ->
			    Dict1 = dict:store({handler,Hid},H,Dict),
			    Dict2 = del_field_handlers_(IFs0,{Prio0,Hid},Dict1),
			    add_field_handlers_(IFs,{Prio,Hid},Dict2)
		    end;
	       true ->
		    io:format("~w[~s]: error: reactor body is not a function/~w\n",
			 [self(),type(Dict),N]),
		    Dict
	    end;
	{OFs1,IFs1} ->
	    io:format("~w[~s]: error: reactor fields ~p not defined\n",
		      [self(),type(Dict),OFs1++IFs1]),
	    Dict
    end;
add_handler_(H,Dict) ->
    io:format("~w[~s]: error: malformed handler ~p\n",
	      [self(),type(Dict),H]),
    Dict.

del_handler_(Hid) ->
    Dict = del_handler_(Hid, get(?REACTOR_DICT)),
    put(?REACTOR_DICT, Dict),
    Dict.

del_handler_(Hid, Dict) ->
    case dict:find({handler,Hid},Dict) of
	error ->
	    Dict;
	{ok,{_,Prio0,_,IFs0,_}} ->
	    Dict1 = dict:erase({handler,Hid},Dict),
	    del_field_handlers_(IFs0,{Prio0,Hid},Dict1)
    end.

add_field_handlers_([F|Fs], PrioID, Dict) ->    
    HandSet = dict:fetch({handset,F}, Dict),
    HandSet1 = ordsets:add_element(PrioID, HandSet),
    Dict1 = dict:store({handset,F}, HandSet1, Dict),
    add_field_handlers_(Fs, PrioID, Dict1);
add_field_handlers_([], _PrioID, Dict) -> 
    Dict.

del_field_handlers_([F|Fs], PrioID, Dict) ->
    HandSet = dict:fetch({handset,F}, Dict),
    HandSet1 = ordsets:del_element(PrioID, HandSet),
    Dict1 = dict:store({handset,F}, HandSet1, Dict),
    del_field_handlers_(Fs, PrioID, Dict1);
del_field_handlers_([], _PrioID, Dict) -> 
    Dict.


fields_not_present([], _Dict) ->
    [];
fields_not_present(void, _Dict) ->
    [];
fields_not_present(F, Dict) when is_atom(F) ->
    case is_field_(F,Dict) of
	false ->
	    [F];
	true ->
	    []
    end;
fields_not_present(Fs, Dict) when is_list(Fs) ->
    fields_not_present_list(Fs, Dict).

fields_not_present_list([F|Fs], Dict) ->
    case is_field_(F,Dict) of
	false ->
	    [F|fields_not_present_list(Fs, Dict)];
	true ->
	    fields_not_present_list(Fs, Dict)
    end;
fields_not_present_list([], _Dict) ->
    [].


fields_values(Fs, Dict) ->
    [ get_value_(F,Dict) || F <- Fs ].


%%
%% Dump reactor field and values to stdout
%%
fields_dump_values() ->
    Dict = get(?REACTOR_DICT),
    fields_dump_values(Dict).

fields_dump_values(Dict) ->
    dict:fold(
      fun({value,F},Value,_Acc) ->
	      case lists:reverse(Value) of
		  [V|Vs] -> io:format("~s = ~w [q=~w]\n",
				      [F, V, lists:reverse(Vs)]);
		  [] ->  io:format("~s = undefined\n", [F])
	      end;
	 (_Key, _Value, Acc) ->
	      Acc
      end, ok, Dict).


connect_(Field, Dst, DstField) ->
    Dict = get(?REACTOR_DICT),
    case is_field_(Field,Dict) of
	false ->
	    ?dbg("~w[~s]: connect_ ~s is not a field\n", 
		 [self(),type(Dict),Field]),
	    false;
	true ->
	    Dict1 = handle_connect(Field,Dst,DstField,Dict),
	    put(?REACTOR_DICT, Dict1),
	    true
    end.

%% Connect "subscriber" field 
handle_connect(Field, Dst, DstField, Dict) ->
    List = list_channel_(Field, Dict),
    Elem = {Dst,DstField},
    case lists:keymember(Elem,1,List) of
	true ->
	    io:format("~w[~s]: already connected ~p => ~p:~p\n",
		      [self(), type(Dict), Field, Dst, DstField]),
	    Dict;
	false ->
	    ?dbg("~w[~s]: connected: ~p => ~p:~p\n", 
		 [self(), type(Dict), Field, Dst,DstField]),
	    {_Ref,Dict1} = add_to_channel_(Field, Elem, List, Dict),
	    Dict1
    end.

disconnect_(Field, Dst, DstField) ->
    Dict = get(?REACTOR_DICT),
    case is_field_(Field,Dict) of
	false ->
	    ?dbg("~w[~s]: disconnect_ ~s is not a field\n", 
		 [self(),type(Dict),Field]),
	    false;
	true ->
	    Dict1 = handle_disconnect(Field,Dst,DstField,Dict),
	    put(?REACTOR_DICT, Dict1),
	    true
    end.

handle_disconnect(Field, Dst, DstField, Dict) ->
    List = list_channel_(Field, Dict),
    Elem = {Dst,DstField},
    case del_from_channel_(Field, Elem, List, Dict) of
	{false,Dict1} ->
	    ?dbg("~w[~s]: not connected ~p => ~p:~p\n",
		 [self(), type(Dict), Field, Dst, DstField]),
	    Dict1;
	{Ref,Dict1} ->
	    ?dbg("~w[~s]: diconnected: ~p => ~p:~p\n", 
		 [self(), type(Dict1), Field, Dst,DstField]),
	    erlang:demonitor(Ref,[flush]),
	    Dict1
    end.
    
%%
%% Apply all function and send outputs.
%%
handle_reaction(Changed0,IDict0) ->
    ?dbg("~w[~s]: handle_reaction: changed ~p\n", 
	 [self(),type(IDict0),ordsets:to_list(Changed0)]),
    %% find all handlers for the Changed set
    PrioIDSet =
	ordsets:fold(
	  fun(F, Set) ->
		  HSet = dict:fetch({handset,F},IDict0),
		  ordsets:union(Set,HSet)
	  end, ordsets:new(), Changed0),
    %% 
    %% Get list of handlers from sorted handler list
    %%
    Handlers = 
	lists:map(fun({_Prio,ID}) ->
			  dict:fetch({handler,ID}, IDict0)
		  end, ordsets:to_list(PrioIDSet)),

    %%
    %% Pop all change values here, also remember if there
    %% is still value in the queue then keep in changed set.
    %%
    {Changed1,IDict1} = 
	ordsets:fold(
	  fun(F, {Set,Dict}) ->
		  case deq_value_(F, Dict) of
		      {true,Dict1} ->
			  {Set,Dict1};
		      {false,Dict1} ->
			  {ordsets:del_element(F,Set),Dict1}
		  end
	  end, {Changed0,IDict0}, Changed0),
    ?dbg("~w[~s]: still changed ~w\n",[self(),type(IDict1),Changed1]),

    %%
    %% Ugly hack, set current version of IDict in process dictionary
    %% to get slightly easier event handlers: I may change my mind :-)
    %%
    put(?REACTOR_DICT, IDict1),

    %%
    %% Iterate over all handlers
    %% and execute handler that match IFs trigger list (any)
    %% Updated is a dictionary with output and output values
    %%
    Updated = execute_handlers(Handlers, Changed0),

    %%
    %%
    %% pick up update dictionary 
    %% 
    IDict2 = get(?REACTOR_DICT),

    %%
    %% Iterate over all original changed values and add the
    %% inputs not already processed.
    %%
    Updated2 =
	lists:foldl(
	  fun(F, UDict) ->
		  case dict:find(F, UDict) of
		      error ->
			  Value = get_value_(F, IDict2),
			  dict:store(F,Value,UDict);
		      {ok,_} ->
			  UDict
		  end
	  end, Updated, Changed0),
    %%
    %% iterate over all updated fields and propagate
    %% to connected reactor fields
    %%
    IDict3 = 
	dict:fold(
	  fun(Field,Value,IDict) ->
		  List = list_channel_(Field,IDict),
		  ?dbg("~w[~s]: propagte ~w = ~w : ~w\n", 
		       [self(),type(IDict),Field,Value,List]),
		  lists:foreach(
		    fun({{Dst,DstField},_Mon}) ->
			    Dst ! {reactor_signal,self(),Field,DstField,Value}
		    end, List),
		  %% poke "output" as single value items - can not build queue
		  %% this should update current value!?
		  set_value_(Field,Value,IDict)
	  end, IDict2, Updated2),

    {Changed1,IDict3}.

execute_handlers(Handlers, Changed0) ->
    ChangedList = ordsets:to_list(Changed0),
    lists:foldl(
      fun(_H={HID,_Prio,OFs,IFs,Body},UDict) ->
	      %% if none of IFs has changed then skip
	      HDict = get(?REACTOR_DICT),
	      ?dbg("~w[~s]: check ~p\n", [self(),type(HDict),_H]),
	      case IFs -- ChangedList of
		  IFs ->
		      UDict;
		  _ ->
		      Args = fields_values(IFs,HDict),
		      ?dbg("~w[~s]: execute ~w changed=~w\n",
			   [self(),type(HDict),{HID,_Prio,OFs,IFs,Args},
			    ChangedList]),
		      put(?REACTOR_HANDLER, HID),
		      try apply(Body, Args) of
			  Value ->
			      set_output_values_(OFs,Value,UDict)
		      catch
			  error:Reason ->
			      Trace = erlang:get_stacktrace(),
			      Es = format_stacktrace(Trace),
			      io:format("~w[~s]: Reactor ~w crash ~p/~w, ~p\n",
					[self(),type(HDict),HID,IFs,Args,
					 Reason]),
			      foreach(fun(E) ->
					      io:format("  ~s\n", [E])
				      end, Es),
			      UDict
		      end
	      end
      end, dict:new(), Handlers).


%% set handler output in update dictionary
set_output_values_([], _Vs, Dict) ->
    Dict;
set_output_values_(void, _V, Dict) ->
    Dict;
set_output_values_(F, V, Dict) when is_atom(F) ->
    dict:store(F,V,Dict);
set_output_values_(Fs, Vs, Dict) ->
    set_output_values_list_(Fs, Vs, Dict).

set_output_values_list_([F|Fs], [V|Vs], Dict) ->
    set_output_values_list_(Fs, Vs, dict:store(F,V,Dict));
set_output_values_list_([], [], Dict) ->
    Dict.

%%
%%
%%
init_channel_(Field, Dict) ->
    dict:store({channel, Field}, [], Dict).

erase_channel_(Field, Dict) ->
    dict:erase({channel,Field}, Dict).

list_channel_(Field, Dict) ->
    dict:fetch({channel,Field}, Dict).

reactors_channel(Field) ->
    reactors_channel_(Field, get(?REACTOR_DICT)).

%% extract all connected reactor processes for field 'Field'
reactors_channel_(Field, Dict) ->
    List = list_channel_(Field,Dict),
    lists:map(fun({{Pid,_},_Mon}) -> Pid end, List).

add_to_channel_(Field, Elem={DstPid,DstField}, List, Dict) 
  when is_pid(DstPid), is_atom(DstField) ->
    Ref = erlang:monitor(process, DstPid),
    Dict1 = dict:store({channel,Field},[{Elem,Ref}|List],Dict),
    Dict2 = dict:store({mon,Ref}, {Field,DstField}, Dict1),
    {Ref,Dict2}.
    
del_from_channel_(Field, Elem={DstPid,DstField}, List, Dict)
  when is_pid(DstPid), is_atom(DstField) ->
    case lists:keytake(Elem,1,List) of
	false ->
	    {false,Dict};
	{value,{_,Ref},List1} ->
	    Dict1 = dict:store({channel,Field},List1,Dict),
	    Dict2 = dict:erase({mon,Ref}, Dict1),
	    {Ref,Dict2}
    end.

    
    
    

%%
%% Field  values
%% {CurrentValue, InputQueue}
%%

init_value_(Field, Value, Dict) ->
    dict:store({value, Field},{Value,queue:new()},Dict).

erase_value_(Field, Dict) ->
    dict:erase({value,Field}, Dict).

%% maybe update last value ?
%%--------------------------------------------------------------------
%% @doc
%%    Set current input value from withing a reactor.
%% @end
%%--------------------------------------------------------------------
-spec set_value(Field::field_name(),Value::term()) -> term().

set_value(Field, Value) ->
    Dict1 = set_value_(Field, Value, get(?REACTOR_DICT)),
    put(?REACTOR_DICT, Dict1),
    Value.

set_value_(Field, Value, Dict) ->
    ?dbg("~w: set_value ~w to ~w\n",[self(),Field,Value]),
    {_Value,Queue} = dict:fetch({value,Field},Dict),
    dict:store({value, Field},{Value,Queue},Dict).

%%--------------------------------------------------------------------
%% @doc
%%    Fetch field value from within a reactor.
%% @end
%%--------------------------------------------------------------------
-spec get_value(Field::field_name()) -> term().

get_value(Field) when is_atom(Field) ->
    get_value_(Field, get(?REACTOR_DICT)).

get_value_(Field, Dict) ->
    {Value,_Queue} = dict:fetch({value,Field}, Dict),
    ?dbg("~w: get_value_ ~w value=~w,queue=~w\n",
	 [self(),Field,Value,_Queue]),
    Value.

enq_value_(Field, Value, Dict) ->
    {Value0,Queue} = dict:fetch({value,Field}, Dict),
    Queue1 = queue:in(Value, Queue),
    dict:store({value,Field}, {Value0,Queue1}, Dict).
%%
%% dequeu a value from input queue, return 
%% {MoreValues::boolean(), Dict':dict()}  where MoreValues signal
%% that the queue is not empty.
%%
deq_value_(Field, Dict) ->
    {_Value,Queue} = dict:fetch({value,Field}, Dict),
    case queue:out(Queue) of
	{empty,_Queue} ->
	    {false,Dict};
	{{value,Value1},Queue1} ->
	    Dict1 = dict:store({value,Field},{Value1,Queue1},Dict),
	    {not queue:is_empty(Queue1), Dict1}
    end.
	    
ordsets_is_empty(Set) ->
    Set =:= ordsets:new().

format_stacktrace(Ts) ->
    MaxDepth = 10,
    MaxLine  = 160,
    format_stacktrace(Ts,MaxDepth,MaxLine).

format_stacktrace([_|_],0,_) ->
    ["..."];
format_stacktrace([{M,F,A}|Ts],D,MaxLine) ->
    Args = format_args(A,MaxLine),
    E = list_to_binary(io_lib:format("~w:~w~s", [M,F,Args])),
    [E | format_stacktrace(Ts,D-1,MaxLine)];
format_stacktrace([{M,F,A,L}|Ts],D,MaxLine) ->
    Args = format_args(A,MaxLine),
    File = proplists:get_value(file, L, "*"),
    Line = proplists:get_value(line, L, 0),
    E = list_to_binary(io_lib:format("~s:~w: ~w:~w/~s", 
				     [File,Line,M,F,Args])),
    [E | format_stacktrace(Ts,D,MaxLine)];
format_stacktrace([],_D,_MaxLine) ->
    [].

format_args(A,_Max) when is_integer(A) ->
    ["/",integer_to_list(A)];
format_args(A,Max) when is_list(A) ->
    ["(",format_arg_list(A,Max),")"].

format_arg_list([],_Max) ->
    "";
format_arg_list(_As,Max) when Max =< 0 ->
    "...";
format_arg_list([A],_Max) ->
    io_lib:format("~w", [A]);
format_arg_list([A|As],Max) ->
    Fmt = list_to_binary(io_lib:format("~w",[A])),
    Max1 = Max - byte_size(Fmt),
    [Fmt,",",format_arg_list(As,Max1)].

