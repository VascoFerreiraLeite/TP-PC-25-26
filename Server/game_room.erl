-module(game_room).
-export([start_link/2, stop/1]).


start_link(MatchmakerPid, Players) ->
    Pid = spawn_link(fun() -> init(MatchmakerPid, Players) end),
    {ok, Pid}.

stop(Pid) ->
    Pid ! stop,
    ok.


init(MatchmakerPid, Players) ->
    io:format("Game Room started with ~p players!~n", [length(Players)]),
    
    MapWidth = 1000.0,
    MapHeight = 1000.0,
    
    lists:foreach(fun({PlayerId, _Username, ClientPid}) -> 
        ClientPid ! {game_started, self(), PlayerId, MapWidth, MapHeight} 
    end, Players),

    InitialState = setup_players(Players, #{}),

    erlang:send_after(33, self(), tick),

    erlang:send_after(120000, self(), match_end),

    loop(MatchmakerPid, InitialState).
loop(MatchmakerPid, State) ->
    receive
        {movement_input, ClientPid, Left, Right, Forward} ->
            NewState = update_player_inputs(State, ClientPid, Left, Right, Forward),
            loop(MatchmakerPid, NewState);

        tick ->
            UpdatedState = apply_dummy_physics(State),
            
            broadcast_state(UpdatedState),
            
            erlang:send_after(33, self(), tick),
            loop(MatchmakerPid, UpdatedState);

        {player_left, ClientPid} ->
            io:format("A player disconnected from the game room.~n"),
            NewState = maps:remove(ClientPid, State),
            loop(MatchmakerPid, NewState);

        match_end ->
            io:format("2 Minute Match Ended!~n"),
            matchmaker:match_ended(MatchmakerPid),
            maps:fold(fun(ClientPid, _, _Acc) -> ClientPid ! stop end, ok, State),
            ok;

        stop ->
            ok;

        _Unknown ->
            loop(MatchmakerPid, State)
    end.

setup_players([], State) -> State;
setup_players([{PlayerId, Username, ClientPid} | Rest], State) ->
    PlayerData = #{
        id => PlayerId,           
        username => Username,
        x => 500.0, y => 500.0,   
        angle => 0.0, mass => 10.0,
        inputs => #{left => 0, right => 0, forward => 0}
    },
    NewState = maps:put(ClientPid, PlayerData, State),
    setup_players(Rest, NewState).

update_player_inputs(State, ClientPid, Left, Right, Forward) ->
    case maps:find(ClientPid, State) of
        {ok, PlayerData} ->
            NewInputs = #{left => Left, right => Right, forward => Forward},
            UpdatedPlayer = PlayerData#{inputs => NewInputs},
            maps:put(ClientPid, UpdatedPlayer, State);
        error ->
            State
    end.

apply_dummy_physics(State) ->
    maps:map(fun(_ClientPid, PlayerData = #{x := X, angle := Angle, inputs := Inputs}) ->
        NewX = case maps:get(forward, Inputs) of 1 -> X + 1.0; 0 -> X end,
        NewAngle = case {maps:get(left, Inputs), maps:get(right, Inputs)} of
            {1, 0} -> Angle - 0.1;
            {0, 1} -> Angle + 0.1;
            _ -> Angle
        end,
        PlayerData#{x => NewX, angle => NewAngle}
    end, State).

%% ====================================================================
%% Game State Broadcasting (The 0x13 Packet)
%% ====================================================================

%% Broadcasts the pre-compiled binary packet to all clients
broadcast_state(State) ->
    %% 1. Build the packet once
    Packet = build_state_packet(State),
    
    %% 2. Send the exact same raw bytes to every connection process
    maps:fold(fun(ClientPid, _PlayerData, _Acc) ->
        ClientPid ! {send_raw_packet, Packet},
        ok
    end, ok, State).

%% Packs the entire game state into our Custom Binary Protocol
build_state_packet(State) ->
    NumPlayers = maps:size(State),

    %% Fold over the map to build the dynamic Players binary block
    PlayersBin = maps:fold(fun(_ClientPid, #{id := Id, x := X, y := Y, angle := Angle, mass := Mass}, AccBin) ->
        Score = 0, %% Placeholder until we implement eating/capturing
        PlayerBin = <<Id:32/integer, X:32/float, Y:32/float, Angle:32/float, Mass:32/float, Score:32/integer>>,
        <<AccBin/binary, PlayerBin/binary>>
    end, <<>>, State),

    %% We don't have food/poison yet, so NumObjects is 0
    NumObjects = 0,
    ObjectsBin = <<>>,

    %% Combine everything into the final 0x13 (19) packet!
    %% Protocol: [19] [NumPlayers] [PlayersBin...] [NumObjects] [ObjectsBin...]
    <<19:8, NumPlayers:8, PlayersBin/binary, NumObjects:16/integer, ObjectsBin/binary>>.