%%% @author Tony Rogvall <tony@rogvall.se>
%%% @copyright (C) 2011, Tony Rogvall
%%% @doc
%%%    Simple output reactor
%%% @end
%%% Created : 10 Dec 2011 by Tony Rogvall <tony@rogvall.se>

-module(reactor_format).


-export([create/2]).

create(ID, Format) ->
    reactor:create(ID, 
		   [
		    {input, undefined}
		   ],
		   
		   [
		    {input_handler,
		     10, void, [input],
		     fun(Input) ->
			     io:format(Format, [Input])
		     end }
		   ]
		   ).

		   
			     
		   
		    
