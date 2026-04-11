-module(game_server).
-export([start/1, accept_loop/1, client_handler/1]).

start(Port) ->
    {ok, LSock} = gen_tcp:listen(Port, [binary, {packet, 2}, {reuseaddr, true}, {active, false}]),
    io:format("Server started on port ~p~n", [Port]),
    accept_loop(LSock).

accept_loop(LSock) ->

    {ok, ClientSocket} = gen_tcp:accept(LSock),
    spawn(fun() -> client_handler(ClientSocket) end),
    accept_loop(LSock).

client_handler(Socket) ->
    case gen_tcp:recv(Socket, 0) of
        {ok, <<ID:8, Payload/binary>>} ->
            handle_packet(ID, Payload, Socket),
            client_handler(Socket); 
        {error, closed} ->
            io:format("Player disconnected.~n");
        {error, Reason} ->
            io:format("Error: ~p~n", [Reason])
    end.

handle_packet(1, Payload, Socket) ->
    io:format("Player joined with data: ~p~n", [Payload]),
    gen_tcp:send(Socket, <<101:8, 100:16, 100:16>>);

handle_packet(2, Payload, Socket) ->
    io:format("Player pressed key: ~p~n", [Payload]),
    gen_tcp:send(Socket, <<2:8, Payload/binary>>);

handle_packet(ID, _Payload, _Socket) ->
    io:format("Received unknown packet ID: ~p~n", [ID]).