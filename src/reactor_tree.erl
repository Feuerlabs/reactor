%%% @author Tony Rogvall <tony@rogvall.se>
%%% @copyright (C) 2011, Tony Rogvall
%%% @doc
%%%    reactor tree test
%%% @end
%%% Created : 11 Dec 2011 by Tony Rogvall <tony@rogvall.se>

-module(reactor_tree).

-export([create_node/2]).

create_node(N,Width) ->
    reactor:create(
      node,
      [
       {x,0},
       {y,0},
       {height,20},
       {width,Width}
      ],
      
      [
       {init_handler,
	10, void, ['@init'],
	fun(_) ->
		Wi = Width / N,
		lists:foreach(
		  fun(I) ->
			  L = create_leaf(I, N, Width, Wi),
			  reactor:connect(self(),width,
					  L, parent_width)
		  end, lists:seq(0,N-1))
	end}
      ]).

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
