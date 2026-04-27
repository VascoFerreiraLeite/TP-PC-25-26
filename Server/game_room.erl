-module(game_room).
-export([start_link/2, stop/1]).


start_link(MatchmakerPid, Players) ->
    Pid = spawn_link(fun() -> init(MatchmakerPid, Players) end),
    {ok, Pid}.

stop(Pid) ->
    Pid ! stop,
    ok.


init(MatchmakerPid, PlayersList) ->
    io:format("Game Room started with ~p players!~n", [length(PlayersList)]),
    MapWidth = 1000.0, MapHeight = 1000.0,
    
    lists:foreach(fun({PlayerId, _Username, ClientPid}) -> 
        ClientPid ! {game_started, self(), PlayerId, MapWidth, MapHeight} 
    end, PlayersList),

    %% 1. Generate Players and Objects
    PlayerMap = setup_players(PlayersList, #{}),
    ObjectMap = generate_objects(50, 10), %% Spawn 50 Green Food, 10 Red Poison

    %% 2. NEW STATE STRUCTURE: Hold both!
    State = #{players => PlayerMap, objects => ObjectMap},

    erlang:send_after(33, self(), tick),
    erlang:send_after(120000, self(), match_end),
    loop(MatchmakerPid, State).

%% Notice we extract the 'players' map directly in the function head now
loop(MatchmakerPid, State = #{players := Players, objects := Objects}) ->
    receive
        {movement_input, ClientPid, Left, Right, Forward} ->
            %% Update the inputs in the PlayerMap
            NewPlayers = update_player_inputs(Players, ClientPid, Left, Right, Forward),
            loop(MatchmakerPid, State#{players => NewPlayers});

        tick ->
            MovedPlayers = apply_dummy_physics(Players),
            
            {FinalPlayers, FinalObjects} = check_object_collisions(MovedPlayers, Objects),
            
            UpdatedState = State#{players => FinalPlayers, objects => FinalObjects},
            broadcast_state(UpdatedState),
            
            erlang:send_after(33, self(), tick),
            loop(MatchmakerPid, UpdatedState);

        {player_left, ClientPid} ->
            NewPlayers = maps:remove(ClientPid, Players),
            loop(MatchmakerPid, State#{players => NewPlayers});

        match_end ->
            io:format("2 Minute Match Ended!~n"),
            matchmaker:match_ended(MatchmakerPid),
            maps:fold(fun(ClientPid, _, _Acc) -> ClientPid ! stop end, ok, Players),
            ok;

        stop -> ok;
        _Unknown -> loop(MatchmakerPid, State)
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
        angle => 0.0, mass => 10.0, score => 0,
        inputs => #{left => 0, right => 0, forward => 0}
    },
    NewState = maps:put(ClientPid, PlayerData, State),
    setup_players(Rest, NewState).

generate_objects(NumFood, NumPoison) ->
    generate_objects(NumFood, NumPoison, 1, #{}).

generate_objects(0, 0, _Id, Acc) -> Acc;
generate_objects(FoodLeft, PoisonLeft, Id, Acc) ->
    %% Random coordinates between 20 and 980
    X = 20.0 + rand:uniform() * 960.0,
    Y = 20.0 + rand:uniform() * 960.0,
    
    {NewFood, NewPoison, Type} = if 
        FoodLeft > 0 -> {FoodLeft - 1, PoisonLeft, 1}; %% Type 1 = Green Food
        true ->         {0, PoisonLeft - 1, 2}         %% Type 2 = Red Poison
    end,

    %% Save radius and type
    Obj = #{id => Id, x => X, y => Y, radius => 5.0, type => Type},
    generate_objects(NewFood, NewPoison, Id + 1, maps:put(Id, Obj, Acc)).

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
%% Collision Detection
%% ====================================================================

check_object_collisions(Players, Objects) ->
    maps:fold(fun(ClientPid, PlayerData, {AccPlayers, AccObjects}) ->
        {UpdatedPlayer, UpdatedObjects} = player_eat_objects(PlayerData, AccObjects),
        {maps:put(ClientPid, UpdatedPlayer, AccPlayers), UpdatedObjects}
    end, {#{}, Objects}, Players).

player_eat_objects(Player = #{x := Px, y := Py, mass := Mass}, Objects) ->
    %% Match Java's exact radius calculation: sqrt(Mass / Pi) * 10
    PRadius = math:sqrt(Mass / math:pi()) * 10.0,
    
    maps:fold(fun(ObjId, Obj = #{x := Ox, y := Oy, radius := ORadius, type := Type}, {AccPlayer, AccObjs}) ->
        %% Pythagorean theorem for distance
        Dist = math:sqrt((Px - Ox)*(Px - Ox) + (Py - Oy)*(Py - Oy)),
        
        case Dist =< (PRadius + ORadius) of
            true ->
                %% COLLISION DETECTED!
                CurrentMass = maps:get(mass, AccPlayer),
                CurrentScore = maps:get(score, AccPlayer),
                
                %% Apply game rules based on object type
                {NewMass, NewScore} = case Type of
                    1 -> {CurrentMass + 1.0, CurrentScore + 10};                %% Green: Grow!
                    2 -> {max(5.0, CurrentMass - 2.0), max(0, CurrentScore - 10)} %% Red: Shrink (Min mass 5.0)
                end,
                
                %% Teleport the eaten object to a new random location
                ReplacementObj = Obj#{
                    x => 20.0 + rand:uniform() * 960.0, 
                    y => 20.0 + rand:uniform() * 960.0
                },
                FinalObjs = maps:put(ObjId, ReplacementObj, AccObjs),
                UpdatedPlayer = AccPlayer#{mass => NewMass, score => NewScore},
                
                {UpdatedPlayer, FinalObjs};
            false ->
                {AccPlayer, AccObjs}
        end
    end, {Player, Objects}, Objects).

broadcast_state(State = #{players := Players}) ->
    Packet = build_state_packet(State),
    
    %% Loop over the Players map to find the ClientPids to send to
    maps:fold(fun(ClientPid, _PlayerData, _Acc) ->
        ClientPid ! {send_raw_packet, Packet},
        ok
    end, ok, Players).

%% Packs BOTH players and objects into the Custom Binary Protocol
build_state_packet(#{players := Players, objects := Objects}) ->
    NumPlayers = maps:size(Players),
    PlayersBin = maps:fold(fun(_ClientPid, #{id := Id, x := X, y := Y, angle := Angle, mass := Mass, score := Score}, AccBin) ->

        PlayerBin = <<Id:32/integer, X:32/float, Y:32/float, Angle:32/float, Mass:32/float, Score:32/integer>>,
        <<AccBin/binary, PlayerBin/binary>>
    end, <<>>, Players),

    %% NEW: Pack the objects loop!
    NumObjects = maps:size(Objects),
    ObjectsBin = maps:fold(fun(_ObjId, #{id := Id, x := X, y := Y, radius := R, type := Type}, AccBin) ->
        ObjBin = <<Id:32/integer, X:32/float, Y:32/float, R:32/float, Type:8/integer>>,
        <<AccBin/binary, ObjBin/binary>>
    end, <<>>, Objects),

    <<19:8, NumPlayers:8, PlayersBin/binary, NumObjects:16/integer, ObjectsBin/binary>>.