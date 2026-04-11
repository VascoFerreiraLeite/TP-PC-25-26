-module(room).
-behaviour(gen_server). %% This is the "code itself" part you asked about

%% API
-export([start_link/1]).
%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

start_link(Config) ->
    gen_server:start_link(?MODULE, Config, []).

init(Config) ->
    %% Start the Game Loop Timer here
    erlang:send_after(50, self(), tick),
    {ok, #{players => [], map_size => Config}}.