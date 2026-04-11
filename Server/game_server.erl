-module(game_server).
-export([start/1, accept_loop/1, client_handler/1]).
-import(player_handler, [handle_packet/3]).
-import(room_manager, [start_link/0]).

start(Port) ->
    {ok, LSock} = gen_tcp:listen(Port, [binary, {packet, 2}, {reuseaddr, true}, {active, false}]),
    io:format("Server started on port ~p~n", [Port]),
    {ok, RoomManager} = room_manager:start_link(),
    io:format("Room manager started"),
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