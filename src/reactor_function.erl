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



    
    
