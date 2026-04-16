-module(player_handler).
-export([handle_packet/4]).
-import(room_manager, [get_room/0]).


handle_packet(1, _Payload, Socket, State) ->
    RoomPid = room_manager:get_room(),
    gen_server:cast(RoomPid, {join, self(), Socket}),
    gen_tcp:send(Socket, <<101:8, 100:16, 100:16>>),
    State#{room => RoomPid}; 

handle_packet(2, Payload, Socket, State = #{room := RoomPid}) ->
    gen_server:cast(RoomPid, {key_pressed, self(), Payload}),
    gen_tcp:send(Socket, <<2:8, Payload/binary>>),
    State;

handle_packet(ID, _Payload, _Socket, State) ->
    io:format("Unknown ID: ~p~n", [ID]),
    State.