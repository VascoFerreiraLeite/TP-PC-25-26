-module(room).
-behaviour(gen_server).


-export([start_link/1]).
-export([init/1, handle_cast/2, handle_info/2]).

start_link(Config) ->
    gen_server:start_link(?MODULE, Config, []).

-record(room_state, {players = [], map_size, key_times=#{}}).

init(Config) ->
    erlang:send_after(50, self(), tick),
    {ok, #room_state{players = [], map_size = Config, key_times=#{}}}.


handle_cast({join, PlayerPid, Socket}, State) ->
    NewPlayers = [{PlayerPid, Socket} | State#room_state.players],
    io:format("Room ~p: Player joined. Total: ~p~n", [self(), length(NewPlayers)]),
    {noreply, State#room_state{players = NewPlayers}};

handle_cast({key_action, PlayerPid,1, Key}, State) ->
    Now = erlang:system_time(millisecond),
    NewTimes = maps:put({PlayerPid, Key}, Now, State#room_state.key_times),
    io:format("Room ~p: Player ~p pressed ~p~n", [self(), PlayerPid, Key]),
    {noreply, State#room_state{key_times = NewTimes}};

handle_cast({key_action, PlayerPid, 0, Key}, State) ->
    Now = erlang:system_time(millisecond),
    Times = State#room_state.key_times,
    case maps:find({PlayerPid, Key}, Times) of
        {ok, StartTime} ->
            Duration = Now - StartTime,
            io:format("Player ~p RELEASED ~c apos ~p ms~n", [PlayerPid, Key, Duration]),
            NewTimes = maps:remove({PlayerPid, Key}, Times),
            {noreply, State#room_state{key_times = NewTimes}};
        error ->
            {noreply, State}
    end.


handle_info(tick, State) ->
    erlang:send_after(50, self(), tick),
    {noreply, State}.