-module(tcp_listener).
-export([start_link/1, accept_loop/1]).

%% Starts the listener on a specific port (e.g., 8080)
start_link(Port) ->
    %% Start listening on the port. 
    %% {active, false} is crucial here! We don't want the listener receiving 
    %% the data; we want to pass the socket to player_connection first.
    {ok, ListenSocket} = gen_tcp:listen(Port, [{active, false}, {packet, raw}, binary, {reuseaddr, true}]),
    io:format("Server listening on port ~p~n", [Port]),
    
    %% Spawn the process that will wait for connections
    Pid = spawn_link(?MODULE, accept_loop, [ListenSocket]),
    {ok, Pid}.

%% The loop that waits for a client to connect
accept_loop(ListenSocket) ->
    %% This function blocks until a client connects
    {ok, ClientSocket} = gen_tcp:accept(ListenSocket),
    io:format("New client connected!~n"),
    
    %% Spawn a new player_connection for this client
    {ok, Pid} = player_connection:start_link(ClientSocket),
    
    %% IMPORTANT: The player_connection start_link already calls 
    %% gen_tcp:controlling_process(Socket, Pid), which transfers ownership!
    
    %% Loop back and wait for the next client
    accept_loop(ListenSocket).