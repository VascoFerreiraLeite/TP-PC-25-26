-module(room).
-behaviour(gen_server).


-export([start_link/1]).
-export([init/1, handle_cast/2, handle_info/2]).

start_link(Config) ->
    gen_server:start_link(?MODULE, Config, []).

-record(room_state, {players = [], map_size}).

init(Config) ->
    erlang:send_after(50, self(), tick),
    {ok, #room_state{players = [], map_size = Config}}.

handle_cast({join, PlayerPid, Socket}, State) ->
    NewPlayers = [{PlayerPid, Socket} | State#room_state.players],
    io:format("Room ~p: Player joined. Total: ~p~n", [self(), length(NewPlayers)]),
    {noreply, State#room_state{players = NewPlayers}};

handle_cast({key_pressed, PlayerPid, KeyData}, State) ->
    io:format("Room ~p: Player ~p pressed ~p~n", [self(), PlayerPid, KeyData]),
    {noreply, State}.

handle_info(tick, State) ->
    erlang:send_after(50, self(), tick),
    {noreply, State}.