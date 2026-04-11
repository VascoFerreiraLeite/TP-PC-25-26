-module(player_handler).
-export([handle_packet/3]).
-import(room_manager, [get_room/0]).

handle_packet(1, Payload, Socket) ->
    io:format("Player joined with data: ~p~n", [Payload]),
    room_manager:get_room(),
    gen_tcp:send(Socket, <<101:8, 100:16, 100:16>>);

handle_packet(2, Payload, Socket) ->
    io:format("Player pressed key: ~p~n", [Payload]),
    gen_tcp:send(Socket, <<2:8, Payload/binary>>);

handle_packet(3, Payload, Socket) ->
    io:format("Requested to join"),
    gen_tcp:send(Socket, <<3:8, 1:8>>),
    room_manager:get_room();

handle_packet(ID, _Payload, _Socket) ->
    io:format("Received unknown packet ID: ~p~n", [ID]).