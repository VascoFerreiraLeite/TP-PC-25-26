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
    
    lists:foreach(fun({_Username, ClientPid}) -> 
        ClientPid ! {joined_game, self()} 
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
setup_players([{Username, ClientPid} | Rest], State) ->
    PlayerData = #{
        username => Username,
        x => 0.0, y => 0.0, angle => 0.0, mass => 10.0,
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

broadcast_state(State) ->
    maps:fold(fun(ClientPid, #{x := X, y := Y, angle := Angle, mass := Mass}, _Acc) ->
        ClientPid ! {game_state_update, X, Y, Angle, Mass},
        ok
    end, ok, State).