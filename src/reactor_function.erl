%%% @author Tony Rogvall <tony@rogvall.se>
%%% @copyright (C) 2011, Tony Rogvall
%%% @doc
%%%    Simple reactor function
%%% @end
%%% Created : 24 Dec 2011 by Tony Rogvall <tony@rogvall.se>

-module(reactor_function).


-export([connect/5]).

connect(Src, SrcField, Function, Dst, DstField) ->
    Handler = {func, 10, output, [input], Function},
    R = reactor:create([], [{fields,[{input,0},{output,0}]},
			    {handlers,[Handler]}]),
    reactor:connect(R, output, Dst, DstField),
    reactor:connect(Src, SrcField, R, input),
    R.



    
    
