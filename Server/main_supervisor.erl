-module(main_supervisor).
-export([start/0, init/0]).

start() ->
    Pid = spawn(?MODULE, init, []),
    {ok, Pid}.

init() ->
    process_flag(trap_exit, true),
    
    io:format("Starting Game Server Supervisor...~n"),
    
    {ok, AccountPid} = account_manager:start(),
    {ok, MatchmakerPid} = matchmaker:start(),
    {ok, ScoreManagerPid} = score_manager:start(),
    {ok, ListenerPid} = tcp_listener:start(8080),

    register(account_manager, AccountPid),
    register(matchmaker, MatchmakerPid),

    State = #{
        AccountPid    => {account_manager, start, []},
        ScoreManagerPid => {score_manager, start, []},
        MatchmakerPid => {matchmaker, start, []},
        ListenerPid   => {tcp_listener, start, [8080]}
    },

    io:format("All services started successfully!~n"),
    loop(State).

loop(State) ->
    receive
        {'EXIT', DeadPid, Reason} ->
            io:format("~n[SUPERVISOR ALERT] Process ~p died! Reason: ~p~n", [DeadPid, Reason]),
            
            case maps:find(DeadPid, State) of
                {ok, {Module, Function, Args}} ->
                    io:format("-> Restarting ~p...~n", [Module]),
                    
                    {ok, NewPid} = apply(Module, Function, Args),
                    
                    if 
                        Module == account_manager -> register(account_manager, NewPid);
                        Module == matchmaker -> register(matchmaker, NewPid);
                        true -> ok
                    end,

                    State1 = maps:remove(DeadPid, State),
                    State2 = maps:put(NewPid, {Module, Function, Args}, State1),
                    
                    io:format("-> ~p successfully recovered! (New PID: ~p)~n", [Module, NewPid]),
                    loop(State2);
                
                error ->
                    loop(State)
            end;

        stop ->
            io:format("Main Supervisor shutting down.~n"),
            ok;

        _Unknown ->
            loop(State)
    end.