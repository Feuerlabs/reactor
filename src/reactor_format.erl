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
		   
			     
		   
		    
