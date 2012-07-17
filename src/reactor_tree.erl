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
%%%    reactor tree test
%%% @end
%%% Created : 11 Dec 2011 by Tony Rogvall <tony@rogvall.se>

-module(reactor_tree).

-export([create_node/2]).
-export([fields/0, handlers/0]).

fields() ->
    [
     {n,0},
     {x,0},
     {y,0},
     {height,20},
     {width,100}
    ].

handlers() ->
    [
     {init_handler,
      10, void, ['@init',width,n],
      fun(_,Width,N) ->
	      Wi = Width / N,
	      lists:foreach(
		fun(I) ->
			L = create_leaf(I, N, Width, Wi),
			reactor:connect(self(),width,
					L, parent_width)
		end, lists:seq(0,N-1))
      end}
    ].

create_node(N,Width) ->
    reactor:create([?MODULE],[{width,Width},{children,N}]).
    

create_leaf(I, N, ParentWidth, Width) ->
    ID = list_to_atom("leaf"++integer_to_list(I)),
    reactor:create(ID,
		   [
		    {x,I*Width},
		    {y,0},
		    {width,Width},
		    {height,10},
		    {parent_width, ParentWidth}
		   ],

		   [
		    {init_handler,
		     10, void, ['@init'],
		     fun(_) ->
			     io:format("~s: created\n", [ID])
		     end},

		    {parent_width_handler,
		     10, [x,width], [parent_width],
		     fun(W) ->
			     Wi = W / N,
			     io:format("~s: new width = ~w\n", [ID,Wi]),
			     [I*Wi, Wi]
		     end
		    }
		   ]).
