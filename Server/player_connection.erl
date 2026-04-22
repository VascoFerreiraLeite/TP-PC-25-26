-module(player_connection).
-export([start_link/1, stop/1]).


start_link(Socket) ->
    Pid = spawn_link(fun() -> init(Socket) end),
    gen_tcp:controlling_process(Socket, Pid),
    {ok, Pid}.

stop(Pid) ->
    Pid ! stop,
    ok.


init(Socket) ->
    inet:setopts(Socket, [{active, once}, {packet, raw}, binary]),
    
    State = #{socket => Socket, username => undefined, game_room => undefined},
    loop(State).

loop(State = #{socket := Socket, game_room := GameRoomPid}) ->
    receive
        {tcp, Socket, BinaryData} ->
            %% 1. Capture the NewState returned by handle_binary_payload!
            NewState = handle_binary_payload(BinaryData, State),
            
            inet:setopts(Socket, [{active, once}]),
            loop(NewState); %% 2. Pass the NewState into the next loop

        {tcp_closed, Socket} ->
            io:format("Client disconnected.~n"),
            if GameRoomPid =/= undefined -> GameRoomPid ! {player_left, self()};
               true -> ok
            end,
            ok; 

        {tcp_error, Socket, Reason} ->
            io:format("TCP Error: ~p~n", [Reason]),
            ok;
        
        {joined_game, RoomPid} ->
            io:format("Joined a game room!~n"),
            loop(State#{game_room => RoomPid});

        {game_state_update, X, Y, Angle, Mass} ->
            Packet = <<2:8, X:32/float, Y:32/float, Angle:32/float, Mass:32/float>>,
            gen_tcp:send(Socket, Packet),
            loop(State);

        stop ->
            gen_tcp:close(Socket),
            ok;

        _Unknown ->
            loop(State)
    end.

%% ====================================================================

handle_binary_payload(<<1:8, Left:8, Right:8, Forward:8>>, State = #{game_room := GameRoomPid}) ->
    if GameRoomPid =/= undefined ->
           GameRoomPid ! {movement_input, self(), Left, Right, Forward};
       true -> 
           ok
    end,
    State; %% Return state unchanged

handle_binary_payload(<<0:8, Rest/binary>>, State) ->
    Username = binary_to_list(Rest),
    io:format("Player ~s wants to login.~n", [Username]),
    
    %% 3. THE MISSING LINK: Tell the matchmaker we want to play!
    %% We use the atom 'matchmaker' because we registered it globally in the main_supervisor.
    matchmaker:join(matchmaker, Username, self()),
    
    %% 4. Return the updated state so the connection remembers who logged in
    State#{username => Username};

handle_binary_payload(Unknown, State) ->
    io:format("Received unknown binary payload: ~p~n", [Unknown]),
    State. %% Return state unchanged