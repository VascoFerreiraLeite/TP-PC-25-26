-module(game_room).
-export([start_link/2, stop/1]).

%% ====================================================================
%% Client API
%% ====================================================================

%% Starts the game room. 
%% MatchmakerPid: To notify when the 2-minute match ends.
%% Players: A list of tuples [{Username, ClientPid}, ...]
start_link(MatchmakerPid, Players) ->
    Pid = spawn_link(fun() -> init(MatchmakerPid, Players) end),
    {ok, Pid}.

stop(Pid) ->
    Pid ! stop,
    ok.

%% ====================================================================
%% Server Implementation
%% ====================================================================

init(MatchmakerPid, Players) ->
    io:format("Game Room started with ~p players!~n", [length(Players)]),
    
    %% 1. Notify all player_connection processes that they joined this room
    lists:foreach(fun({_Username, ClientPid}) -> 
        ClientPid ! {joined_game, self()} 
    end, Players),

    %% 2. Setup initial game state (Dummy starting positions & mass)
    InitialState = setup_players(Players, #{}),

    %% 3. Start the Game Loop Tick (30 frames per second = ~33ms)
    erlang:send_after(33, self(), tick),

    %% 4. Start the 2-minute match timer (120,000 ms)
    erlang:send_after(120000, self(), match_end),

    %% Loop needs to hold both the Matchmaker PID and the internal game state
    loop(MatchmakerPid, InitialState).

loop(MatchmakerPid, State) ->
    receive
        %% --- Receive inputs from player_connection ---
        {movement_input, ClientPid, Left, Right, Forward} ->
            %% Update the input state for this specific player
            NewState = update_player_inputs(State, ClientPid, Left, Right, Forward),
            loop(MatchmakerPid, NewState);

        %% --- The Game Loop Tick ---
        tick ->
            %% 1. Apply dummy physics based on current inputs
            UpdatedState = apply_dummy_physics(State),
            
            %% 2. Broadcast the new positions back to the clients
            broadcast_state(UpdatedState),
            
            %% 3. Schedule the next tick
            erlang:send_after(33, self(), tick),
            loop(MatchmakerPid, UpdatedState);

        %% --- A player disconnected ---
        {player_left, ClientPid} ->
            io:format("A player disconnected from the game room.~n"),
            %% Remove them from the state map
            NewState = maps:remove(ClientPid, State),
            loop(MatchmakerPid, NewState);

        %% --- The 2-minute timer finished ---
        match_end ->
            io:format("2 Minute Match Ended!~n"),
            %% Tell the matchmaker we are done so it can free up a slot
            matchmaker:match_ended(MatchmakerPid),
            %% Tell all player connections to close
            maps:fold(fun(ClientPid, _, _Acc) -> ClientPid ! stop end, ok, State),
            ok; %% Process naturally dies

        stop ->
            ok;

        _Unknown ->
            loop(MatchmakerPid, State)
    end.

%% ====================================================================
%% Internal Game Logic & Dummy Physics
%% ====================================================================

%% Populates the initial state map. 
%% We use ClientPid as the key for ultra-fast lookups when receiving inputs.
setup_players([], State) -> State;
setup_players([{Username, ClientPid} | Rest], State) ->
    %% Starting stats: X=0.0, Y=0.0, Angle=0.0, Mass=10.0
    %% We also store the current "keys pressed" state.
    PlayerData = #{
        username => Username,
        x => 0.0, y => 0.0, angle => 0.0, mass => 10.0,
        inputs => #{left => 0, right => 0, forward => 0}
    },
    NewState = maps:put(ClientPid, PlayerData, State),
    setup_players(Rest, NewState).

%% Updates the input variables for a specific player
update_player_inputs(State, ClientPid, Left, Right, Forward) ->
    case maps:find(ClientPid, State) of
        {ok, PlayerData} ->
            NewInputs = #{left => Left, right => Right, forward => Forward},
            UpdatedPlayer = PlayerData#{inputs => NewInputs},
            maps:put(ClientPid, UpdatedPlayer, State);
        error ->
            %% Player might have disconnected
            State
    end.

%% A very simple physics engine just to test the connection.
%% It blindly increments X or Angle if the keys are held down.
apply_dummy_physics(State) ->
    maps:map(fun(_ClientPid, PlayerData = #{x := X, angle := Angle, inputs := Inputs}) ->
        %% If forward is 1, move X. If left/right are 1, change angle.
        NewX = case maps:get(forward, Inputs) of 1 -> X + 1.0; 0 -> X end,
        NewAngle = case {maps:get(left, Inputs), maps:get(right, Inputs)} of
            {1, 0} -> Angle - 0.1;
            {0, 1} -> Angle + 0.1;
            _ -> Angle
        end,
        PlayerData#{x => NewX, angle => NewAngle}
    end, State).

%% Sends the updated coordinates to the connection processes.
%% NOTE: For this basic test, we are just sending the player their OWN coordinates.
%% Later, you will want to loop through and send EVERY player's coordinates to EVERY client.
broadcast_state(State) ->
    maps:fold(fun(ClientPid, #{x := X, y := Y, angle := Angle, mass := Mass}, _Acc) ->
        %% Send the message format that player_connection is expecting
        ClientPid ! {game_state_update, X, Y, Angle, Mass},
        ok
    end, ok, State).