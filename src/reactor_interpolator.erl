%%% @author Tony Rogvall <tony@rogvall.se>
%%% @copyright (C) 2011, Tony Rogvall
%%% @doc
%%%   interpolation reactor
%%% @end
%%% Created :  9 Dec 2011 by Tony Rogvall <tony@rogvall.se>

-module(reactor_interpolator).

-behaviour(reactor).
-export([fields/0, handlers/0]).
-export([create/2]).

-export([create/3, create_integer/2]).
-export([search_/2]).
-export([interpolate_/2, interpolate_/3]).

fields() ->
    [
     {input, 0.0},
     {output, undefined},
     {points, {}},
     {vf, fun(V) -> V end}
    ].

handlers() ->
    [
     {input_handler, 
      10, output, [input,points,vf],
      fun(S,Points,Vf) ->
	      interpolate_(S, Points, Vf)
      end
     }
    ].

%%
%% Create an interpolator. Points is a tuple of pairs on form
%% { {T0,V0}, ... {Tn,Vn} }
%% Where 0.0 <= T0 < T1 .. < Tn <= 1.0
%% And Vi are scalar or vector of numbers
%%
create(Name,Points) when is_tuple(Points) ->
    create(Name, Points, fun(V) -> V end).

%% interpolator returning integer values only
create_integer(Name,Points) ->
    create(Name,Points,fun(V) -> trunc(V) end).

create(Name,Points, Vf) when is_tuple(Points), is_function(Vf,1) ->
    reactor:create([?MODULE],[{'@name',Name},{points,Points},{vf, Vf}]).

interpolate_(S, Tuple) ->
    interpolate_(S, Tuple, fun(V) -> V end).

interpolate_(S, Tuple, Vf) ->
    I = search_(S, Tuple),
    {T0,V0} = element(I,Tuple),
    {T1,V1} = element(I+1,Tuple),
    T = 1-(T1-S)/(T1-T0),
    value_(T, V0, V1, Vf).

value_(T, V0, V1, Vf) when is_number(V0), is_number(V1) ->
    Vf(V0 + (V1-V0)*T);
value_(T, V0, V1, Vf) when is_tuple(V0), is_tuple(V1), size(V0) =:= size(V1) ->
    value_tuple_(T, size(V0), V0, V1, Vf, []).

value_tuple_(_T, 0, _V0, _V1, _Vf, Acc) ->
    list_to_tuple(Acc);
value_tuple_(T, I, V0, V1, Vf, Acc) ->
    W0 = element(I,V0),
    W1 = element(I,V1),
    value_tuple_(T, I-1, V0, V1, Vf, [Vf(W0 + (W1-W0)*T) | Acc]).

search_(Val, Tuple) when is_number(Val), is_tuple(Tuple) ->
    N = size(Tuple),
    Low  = element(1, element(1,Tuple)),
    High = element(1, element(N,Tuple)),
    if Val == Low  -> 1;
       Val == High -> N-1;
       Val > Low, Val < High ->
	    search_(Val, Tuple, 1, N)
    end.


search_(_Val, _Tpl, Mid, Mid) ->    
    Mid;
search_(Val, Tpl, Start, Stop) ->
    Mid = (Start + Stop) div 2,
    if Val < element(1,element(Mid, Tpl)) ->
	    search_(Val, Tpl, Start, Mid);
       Val >= element(1,element(Mid+1, Tpl)) ->
	    search_(Val, Tpl, Mid+1, Stop);
       true ->
	    Mid
    end.
