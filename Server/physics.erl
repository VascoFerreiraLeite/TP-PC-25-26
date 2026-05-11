-module(physics).
-export([update_movement/4, check_poison_collisions/2, check_captures/2, radius_from_mass/1]).

-define(MIN_MASS, 10.0). % Massa mínima definida [cite: 26]
-define(PI, 3.141592653589793).

radius_from_mass(Mass) ->
    EffectiveMass = max(Mass, ?MIN_MASS),
    math:sqrt(EffectiveMass / ?PI).

update_movement({X, Y, Vx, Vy, Angle, Mass, Torque, Force}, {IsForward, IsLeft, IsRight}, DeltaTime, {MaxX, MaxY}) ->
    
    LinAcc = if IsForward -> Force / Mass; true -> 0.0 end,
    
    AngAccLeft = if IsLeft -> Torque / Mass; true -> 0.0 end,
    AngAccRight = if IsRight -> -(Torque / Mass); true -> 0.0 end,
    AngAcc = AngAccLeft + AngAccRight,

    NewAngle = Angle + (AngAcc * DeltaTime),
    
    NewVx = Vx + (LinAcc * math:cos(NewAngle) * DeltaTime),
    NewVy = Vy + (LinAcc * math:sin(NewAngle) * DeltaTime),

    TempX = X + (NewVx * DeltaTime),
    TempY = Y + (NewVy * DeltaTime),

    R = radius_from_mass(Mass),
    {FinalX, FinalVx} = apply_bounds(TempX, NewVx, R, MaxX),
    {FinalY, FinalVy} = apply_bounds(TempY, NewVy, R, MaxY),
    
    {FinalX, FinalY, FinalVx, FinalVy, NewAngle}.

apply_bounds(Pos, Vel, Radius, MaxBound) ->
    if
        Pos - Radius < 0 -> {Radius, 0.0};
        Pos + Radius > MaxBound -> {MaxBound - Radius, 0.0};
        true -> {Pos, Vel}
    end.

distance(X1, Y1, X2, Y2) ->
    math:sqrt(math:pow(X2 - X1, 2) + math:pow(Y2 - Y1, 2)).

check_poison_collisions(PlayerState = {X, Y, Mass}, PoisonObjects) ->
    R_Player = radius_from_mass(Mass),
    
    {SurvivedPoison, MassLost} = lists:foldl(
        fun(Poison = {PX, PY, PMass}, {Keep, Damage}) ->
            R_Poison = radius_from_mass(PMass),
            Dist = distance(X, Y, PX, PY),
            
            if Dist < (R_Player + R_Poison) -> 
               true -> 
                   {[Poison | Keep], Damage} 
            end
        end, {[], 0.0}, PoisonObjects),
        
    NewMass = max(?MIN_MASS, Mass - MassLost),
    {NewMass, SurvivedPoison}.

can_capture({X1, Y1, Mass1}, {X2, Y2, Mass2}) ->
    if Mass1 > Mass2 ->
        R1 = radius_from_mass(Mass1),
        R2 = radius_from_mass(Mass2),
        Dist = distance(X1, Y1, X2, Y2), 
        Dist + R2 =< R1;
    true ->
        false
    end.