-module(matchmaker).
-export([start_link/0, join/3, match_ended/1, stop/1]).

%% ====================================================================
%% Client API
%% ====================================================================

start_link() ->
    Pid = spawn_link(fun() -> init() end),
    {ok, Pid}.

%% Called by a player's connection process when they want to play.
%% Wait until such is possible.
join(Pid, Username, ClientPid) ->
    Ref = make_ref(),
    Pid ! {{join, Username, ClientPid}, self(), Ref},
    receive
        {Ref, Reply} -> Reply
    after 5000 -> 
        {error, timeout}
    end.

%% Called by a game_room when its 2-minute timer finishes.
match_ended(Pid) ->
    Pid ! match_ended,
    ok.

stop(Pid) ->
    Pid ! stop,
    ok.

%% ====================================================================
%% Server Implementation
%% ====================================================================

init() ->
    %% Initial state: empty queue, 0 active matches, no timer running
    State = #{queue => [], active => 0, timer => undefined},
    loop(State).

loop(State) ->
    receive
        %% --- A new player joins the queue ---
        {{join, Username, ClientPid}, CallerPid, Ref} ->
            Queue = maps:get(queue, State),
            %% Add the new player to the back of the queue
            NewQueue = Queue ++ [{Username, ClientPid}], 
            CallerPid ! {Ref, ok},
            %% Check if we can start a match now that someone joined
            NewState = check_queue(State#{queue => NewQueue}),
            loop(NewState);

        %% --- The 3-player timer finished! ---
        start_3_player_match ->
            %% Reset the timer in our state since it just fired
            StateNoTimer = State#{timer => undefined},
            %% Try to force start a match with 3 players
            NewState = try_start_match(StateNoTimer, 3),
            loop(NewState);

        %% --- A 2-minute match has ended ---
        match_ended ->
            Active = maps:get(active, State),
            %% Decrement active matches (ensure it doesn't drop below 0)
            DecrementedState = State#{active => max(0, Active - 1)},
            %% Now that a slot opened up, check if the queue was waiting!
            NewState = check_queue(DecrementedState),
            loop(NewState);

        stop ->
            ok;

        _Unknown ->
            loop(State)
    end.

%% ====================================================================
%% Internal Match Logic (The "Brain")
%% ====================================================================

%% Checks the queue and acts based on your exact rules.
check_queue(State = #{queue := Q, active := Active, timer := Timer}) ->
    if
        %% Rule 1: We have 4 players and room for a match (Active < 4) [cite: 16, 17]
        length(Q) >= 4 andalso Active < 4 ->
            cancel_timer(Timer), % Stop the 3-player timer if it was running
            {PlayersToStart, RemainingQ} = lists:split(4, Q),
            start_game_room(PlayersToStart),
            %% Recursively check the queue in case there are 8+ players waiting
            check_queue(State#{queue => RemainingQ, active => Active + 1, timer => undefined});

        %% Rule 2: We have 3 players, room for a match, but NO timer running yet [cite: 16, 17]
        length(Q) == 3 andalso Active < 4 andalso Timer == undefined ->
            %% Start a timer (e.g., 10 seconds / 10000 ms) to wait for a 4th player
            %% erlang:send_after/3 sends a message to self() in the future.
            NewTimer = erlang:send_after(10000, self(), start_3_player_match),
            State#{timer => NewTimer};

        %% Rule 3: We have 3+ players, but all 4 match slots are full. 
        %% They must wait. Do not start a timer yet.
        length(Q) >= 3 andalso Active >= 4 ->
            cancel_timer(Timer),
            State#{timer => undefined};

        %% Rule 4: Not enough players (1 or 2). Just wait.
        true ->
            State
    end.

%% Forces a match to start if the timer finishes and conditions are still met.
try_start_match(State = #{queue := Q, active := Active}, NeededPlayers) ->
    if
        length(Q) >= NeededPlayers andalso Active < 4 ->
            {PlayersToStart, RemainingQ} = lists:split(NeededPlayers, Q),
            start_game_room(PlayersToStart),
            %% Check if the leftover players can form another match
            check_queue(State#{queue => RemainingQ, active => Active + 1});
        true ->
            %% If this hits, the match slot got filled by something else 
            %% while the timer was ticking. Just keep waiting.
            State
    end.

%% Safely cancels an Erlang timer.
cancel_timer(undefined) -> ok;
cancel_timer(Timer) -> erlang:cancel_timer(Timer).

%% Placeholder: This is where you will eventually spawn your game_room.
start_game_room(Players) ->
    %% Later, this will be something like: game_room:start_link(Players)
    io:format(">>> SPANWING GAME ROOM WITH PLAYERS: ~p~n", [Players]),
    ok.