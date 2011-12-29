%%% @author Tony Rogvall <tony@rogvall.se>
%%% @copyright (C) 2011, Tony Rogvall
%%% @doc
%%%    Simple output reactor
%%% @end
%%% Created : 10 Dec 2011 by Tony Rogvall <tony@rogvall.se>

-module(reactor_format).

-behaviour(reactor).
-export([fields/0, handlers/0]).
-export([create/2]).

fields() ->
    [
     {format, ""},
     {input, undefined}    
    ].

handlers() ->
    [
     {input_handler,
      10, void, [input,format],
      fun(Input,Format) ->
	      io:format(Format, [Input])
      end 
     }
    ].

create(Name, Format) ->
    reactor:create([?MODULE], [{'@name',Name},{format,Format}]).
		   
			     
		   
		    
