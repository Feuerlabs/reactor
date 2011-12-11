%%% @author Tony Rogvall <tony@rogvall.se>
%%% @copyright (C) 2011, Tony Rogvall
%%% @doc
%%%    reactor demo
%%% @end
%%% Created :  8 Dec 2011 by Tony Rogvall <tony@rogvall.se>

-module(reactor_demo).
-export([test0/0]).
-export([test1/0]).

test0() ->
    Values = {{0.0,{1,1}},{0.5,{20,20}},{1.0,{30,1}}},
    T = reactor_timer:create(t1, 5000),
    P = reactor_interpolator:create_integer(p1,Values),
    reactor:connect(T, time, P, input),
    F0 = reactor_format:create(f0, "time = ~p\n"),
    reactor:connect(T, time, F0, input),
    F1 = reactor_format:create(f1, "value = ~p\n"),
    reactor:connect(P, output, F1, input),
    reactor:set(T, activate, true).


test1() ->
    A = reactor:create(
	  a_reactor,
	  [a1,a2,a3,b1,b2],
	  [{10, b1, [a1],    fun(A1) -> A1+1 end},
	   {20, b2, [a2,a3], fun(A2,A3) -> A2+A3 end}]),
    
    B = reactor:create(
	  b_reactor,
	  [x1,x2,y1,y2,y3],
	  [{10, y1, [x1,x2], fun(X1,X2) -> X1*X2 end},
	   {20, y2, [x1,x2], fun(X1,X2) -> X1+X2 end},
	   {30, y3, [x1,x2], fun(X1,X2) -> X1-X2 end}]),

    %% consumer
    C = reactor_format:create(consumer, "consumer: ~p\n"),

    reactor:connect(A, b1, B, x1),
    reactor:connect(A, b2, B, x2),
    reactor:connect(B, y2, C, input),

    %% producer
    spawn(
      fun() -> loop(fun(I) -> 
			    reactor:set(A,a1,I),
			    reactor:set(A,a2,2*I),
			    reactor:set(A,a3,3*I),
			    timer:sleep(1000)
		    end, 1) end).
    
loop(Fun, I) ->
    Fun(I),
    loop(Fun,I+1).



