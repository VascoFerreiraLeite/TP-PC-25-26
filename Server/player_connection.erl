-module(player_connection).
-export([start_link/1, stop/1]).

start_link(Socket) ->
    Pid = spawn_link(fun() -> init(Socket) end),
    gen_tcp:controlling_process(Socket, Pid),
    {ok, Pid}.

stop(Pid) -> Pid ! stop, ok.

init(Socket) ->
    inet:setopts(Socket, [{active, once}, {packet, raw}, binary]),
    State = #{socket => Socket, username => undefined, game_room => undefined},
    loop(State).

loop(State = #{socket := Socket, game_room := GameRoomPid}) ->
    receive
        {tcp, Socket, BinaryData} ->
            NewState = handle_binary_payload(BinaryData, State),
            inet:setopts(Socket, [{active, once}]),
            loop(NewState);

        {tcp_closed, Socket} ->
            io:format("Client disconnected.~n"),
            if GameRoomPid =/= undefined -> GameRoomPid ! {player_left, self()};
               true -> ok
            end,
            ok;

        {tcp_error, Socket, Reason} ->
            io:format("TCP Error: ~p~n", [Reason]),
            ok;
        
        {game_started, RoomPid, PlayerId, MapWidth, MapHeight} ->
            io:format("Game Started! My Player ID is ~p~n", [PlayerId]),
            
            Packet = <<18:8, PlayerId:32/integer, MapWidth:32/float, MapHeight:32/float>>,
            gen_tcp:send(Socket, Packet),
            
            loop(State#{game_room => RoomPid});

        {send_raw_packet, Packet} ->
            gen_tcp:send(Socket, Packet),
            loop(State);

        stop ->
            gen_tcp:close(Socket),
            ok;

        _Unknown ->
            loop(State)
    end.

%% ====================================================================
%% Binary Payload Routing
%% ====================================================================

%% ====================================================================
%% Binary Payload Routing (Recursive for TCP Streams!)
%% ====================================================================

%% Base Case: The binary is empty, we are done processing this chunk!
handle_binary_payload(<<>>, State) ->
    State;

%% 0x01: REGISTER
handle_binary_payload(<<1:8, UserLen:16, UserBin:UserLen/binary, PassLen:16, PassBin:PassLen/binary, Rest/binary>>, State = #{socket := Socket}) ->
    Username = binary_to_list(UserBin),
    Password = binary_to_list(PassBin),
    case account_manager:register(account_manager, Username, Password) of
        ok -> send_auth_response(Socket, 1, "Registered successfully.");
        {error, _} -> send_auth_response(Socket, 0, "Username already exists.")
    end,
    %% Recursively process any remaining bytes!
    handle_binary_payload(Rest, State);

%% 0x02: LOGIN & QUEUE
handle_binary_payload(<<2:8, UserLen:16, UserBin:UserLen/binary, PassLen:16, PassBin:PassLen/binary, Rest/binary>>, State = #{socket := Socket}) ->
    Username = binary_to_list(UserBin),
    Password = binary_to_list(PassBin),
    NewState = case account_manager:authenticate(account_manager, Username, Password) of
        true ->
            send_auth_response(Socket, 1, "Login successful. Entering Matchmaker queue..."),
            matchmaker:join(matchmaker, Username, self()),
            State#{username => Username};
        false ->
            send_auth_response(Socket, 0, "Invalid username or password."),
            State
    end,
    handle_binary_payload(Rest, NewState);

%% 0x03: CANCEL ACCOUNT
handle_binary_payload(<<3:8, UserLen:16, UserBin:UserLen/binary, PassLen:16, PassBin:PassLen/binary, Rest/binary>>, State = #{socket := Socket}) ->
    Username = binary_to_list(UserBin),
    Password = binary_to_list(PassBin),
    case account_manager:cancel(account_manager, Username, Password) of
        ok -> send_auth_response(Socket, 1, "Account successfully deleted.");
        {error, _} -> send_auth_response(Socket, 0, "Failed to delete account.")
    end,
    handle_binary_payload(Rest, State);

%% 0x04: MOVEMENT
handle_binary_payload(<<4:8, Left:8, Right:8, Forward:8, Rest/binary>>, State = #{game_room := GameRoomPid}) ->
    if GameRoomPid =/= undefined ->
           GameRoomPid ! {movement_input, self(), Left, Right, Forward};
       true -> ok
    end,
    handle_binary_payload(Rest, State);

%% Catch-All Fragmented Data
handle_binary_payload(Unknown, State) ->
    io:format("Received unknown/fragmented payload: ~p~n", [Unknown]),
    State.

%% ====================================================================
%% Helper Functions
%% ====================================================================

%% Sends the 0x10 Auth Response packet
send_auth_response(Socket, Status, Message) ->
    MsgBin = list_to_binary(Message),
    MsgLen = byte_size(MsgBin),
    %% Protocol: [16] [Status: Byte] [MsgLen: Short] [Message: String]
    Packet = <<16:8, Status:8, MsgLen:16/integer, MsgBin/binary>>,
    gen_tcp:send(Socket, Packet).