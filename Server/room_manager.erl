-module(room_manager).
-behaviour(gen_server).

-export([start_link/0, get_room/0]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {
    rooms = [] :: [pid()]
}).


start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

get_room() ->
    gen_server:call(?SERVER, get_room).


init([]) ->
    io:format("Room Manager initialized.~n"),
    {ok, #state{rooms = []}}.

handle_call(get_room, _From, State) ->
    case State#state.rooms of
        [] ->
            {ok, NewRoomPid} = room:start_link(#{width => 1000, height => 1000}),
            io:format("Created first room: ~p~n", [NewRoomPid]),
            {reply, NewRoomPid, State#state{rooms = [NewRoomPid]}};
        
        [FirstRoom | _] ->
            {reply, FirstRoom, State}
    end;

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% Handle room process crashes
handle_info({'EXIT', Pid, _Reason}, State) ->
    NewRooms = lists:delete(Pid, State#state.rooms),
    io:format("Room ~p closed. Remaining rooms: ~p~n", [Pid, length(NewRooms)]),
    {noreply, State#state{rooms = NewRooms}};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.