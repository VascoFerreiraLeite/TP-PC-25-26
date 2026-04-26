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
    {StartX, StartY} = case PlayerId of
        1 -> {100.0, 100.0};  
        2 -> {900.0, 100.0};  
        3 -> {100.0, 900.0};  
        4 -> {900.0, 900.0};  
        _ -> {500.0, 500.0}   
    end,

    PlayerData = #{
        id => PlayerId,
        username => Username,
        x => StartX, y => StartY, 
        vx => 0.0, vy => 0.0,     %% NEW: We must track velocity!
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
    maps:map(fun(_ClientPid, PlayerData = #{x := X, y := Y, vx := Vx, vy := Vy, angle := Angle, mass := Mass, inputs := Inputs}) ->
        
        %% 1. Torque (Rotation) - Inversely proportional to Mass
        %% Lighter players turn faster, heavier players turn slower!
        TurnSpeed = 1.5 / Mass, 
        NewAngle = case {maps:get(left, Inputs), maps:get(right, Inputs)} of
            {1, 0} -> Angle - TurnSpeed;
            {0, 1} -> Angle + TurnSpeed;
            _ -> Angle
        end,

        %% 2. Force (Acceleration) - Inversely proportional to Mass
        Thrust = case maps:get(forward, Inputs) of
            1 -> 15.0 / Mass; 
            0 -> 0.0
        end,

        %% 3. Trigonometry! Apply thrust in the exact direction we are facing
        NewVx = Vx + (math:cos(NewAngle) * Thrust),
        NewVy = Vy + (math:sin(NewAngle) * Thrust),

        %% 4. Apply Space Friction (Drag) so they don't slide forever
        FinalVx = NewVx * 0.95,
        FinalVy = NewVy * 0.95,

        %% 5. Update Position
        CalculatedX = X + FinalVx,
        CalculatedY = Y + FinalVy,

        %% 6. PDF Requirement: Wall Collisions!
        %% Maintain tangential velocity, but prevent them from leaving the 1000x1000 map.
        %% We subtract a 20px radius buffer so they don't visually clip out of the window.
        BoundedX = max(20.0, min(980.0, CalculatedX)),
        BoundedY = max(20.0, min(980.0, CalculatedY)),

        %% If they hit a wall, kill the velocity pushing INTO the wall, but keep tangential!
        WallVx = case BoundedX == CalculatedX of true -> FinalVx; false -> 0.0 end,
        WallVy = case BoundedY == CalculatedY of true -> FinalVy; false -> 0.0 end,

        PlayerData#{
            x => BoundedX, y => BoundedY,
            vx => WallVx, vy => WallVy,
            angle => NewAngle
        }
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