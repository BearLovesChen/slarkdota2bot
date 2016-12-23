--[[
    StateMachine is a table
    the key "STATE" stores the STATE of Slark 
    other key value pairs: key is the string of state value is the function of the State. 
    each frame DOTA2 will call Think()
    Then Think() will call the function of current state.
]]

local ValveAbilityUse = require(GetScriptDirectory().."/ability_item_usage_slark");
local Constant = require(GetScriptDirectory().."/constant_each_side");
local DotaBotUtility = require(GetScriptDirectory().."/utility");

local STATE_IDLE = "STATE_IDLE";
local STATE_ATTACKING_CREEP = "STATE_ATTACKING_CREEP";
local STATE_KILL = "STATE_KILL";
local STATE_RETREAT = "STATE_RETREAT";
local STATE_FARMING = "STATE_FARMING";
local STATE_GOTO_COMFORT_POINT = "STATE_GOTO_COMFORT_POINT";
local STATE_FIGHTING = "STATE_FIGHTING";
local STATE_RUN_AWAY = "STATE_RUN_AWAY";

local SlarkRetreatHPThreshold = 0.3;
local SlarkRetreatMPThreshold = 0.1;

local STATE = STATE_IDLE;

LANE = LANE_BOT

----------------- local utility functions reordered for lua local visibility--------
--Perry's code from http://dev.dota2.com/showthread.php?t=274837
local function PerryGetHeroLevel()
    local npcBot = GetBot();
    local respawnTable = {8, 10, 12, 14, 16, 26, 28, 30, 32, 34, 36, 46, 48, 50, 52, 54, 56, 66, 70, 74, 78,  82, 86, 90, 100};
    local nRespawnTime = npcBot:GetRespawnTime() +1 -- It gives 1 second lower values.
    for k,v in pairs (respawnTable) do
        if v == nRespawnTime then
        return k
        end
    end
end


local function TryToUpgradeAbility(AbilityName)
    local npcBot = GetBot();
    local ability = npcBot:GetAbilityByName(AbilityName);
    if ability:CanAbilityBeUpgraded() then
        ability:UpgradeAbility();
        return true;
    end
    return false;
end

local function ConsiderFighting(StateMachine)
    local ShouldFight = false;
    local npcBot = GetBot();

    local NearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1000, true, BOT_MODE_NONE );
    if(NearbyEnemyHeroes ~= nil) then
        for _,npcEnemy in pairs( NearbyEnemyHeroes )
        do
            if(npcBot:WasRecentlyDamagedByHero(npcEnemy,1)) then
                -- got the enemy who attacks me, kill him!--
                StateMachine["EnemyToKill"] = npcEnemy;
                ShouldFight = true;
                break;
            elseif(GetUnitToUnitDistance(npcBot,npcEnemy) < 500) then
                StateMachine["EnemyToKill"] = npcEnemy;
                ShouldFight = true;
                break;
            end
        end
    end
    return ShouldFight;
end


local function ConsiderAttackCreeps()
    -- there are creeps try to attack them --
    --print("ConsiderAttackCreeps");
    local npcBot = GetBot();

    local EnemyCreeps = npcBot:GetNearbyCreeps(1000,true);
    local AllyCreeps = npcBot:GetNearbyCreeps(1000,false);

    -- Check if we're already using an ability
	if ( npcBot:IsUsingAbility() ) then return end;

    local abilityDark = npcBot:GetAbilityByName( "slark_dark_pact" );
	local abilityDance = npcBot:GetAbilityByName( "slark_shadow_dance" );
	local abilityPounce = npcBot:GetAbilityByName( "slark_pounce" );

    -- Consider using each ability
    
	local castPounceDesire, castPounceTarget = ConsiderPounce(abilityPounce);
	local castDarkDesire, castDark = ConsiderDarkPact(abilityDark);
	local castDanceDesire, castDance = ConsiderShadowDance(abilityDance);

    if ( castDarkDesire > castPounceDesire and castDarkDesire > castDanceDesire ) 
	then
		npcBot:Action_UseAbilityOnEntity( abilityDark, castDark );
		return;
	end

	if ( castPounceDesire > 0 ) 
	then
		npcBot:Action_UseAbilityOnTarget( abilityPounce, castPounceTarget );
		return;
	end

	if ( castDanceDesire > 0 ) 
	then
		npcBot:Action_UseAbility( abilityDance, castDance );
		return;
	end

    --print("desires: " .. castPounceDesire .. " " .. castDarkDesire .. " " .. castDanceDesire);

    --If we dont cast ability, just try to last hit.

    local lowest_hp = 100000;
    local weakest_creep = nil;
    for creep_k,creep in pairs(EnemyCreeps)
    do 
        --npcBot:GetEstimatedDamageToTarget
        local creep_name = creep:GetUnitName();
        --print(creep_name);
        if(creep:IsAlive()) then
             local creep_hp = creep:GetHealth();
             if(lowest_hp > creep_hp) then
                 lowest_hp = creep_hp;
                 weakest_creep = creep;
             end
         end
    end

    if(weakest_creep ~= nil) then
        -- Trying to last hit
        if(DotaBotUtility.NilOrDead(npcBot:GetAttackTarget()) and 
        lowest_hp < npcBot:GetBaseDamageVariance( true, weakest_creep, 1.0, DAMAGE_TYPE_PHYSICAL + 20 )) then
            npcBot:Action_AttackUnit(weakest_creep,true);
            return;
        end
        weakest_creep = nil;
        
    end

    for creep_k,creep in pairs(AllyCreeps)
    do 
        --npcBot:GetBaseDamageVariance
        local creep_name = creep:GetUnitName();
        --print(creep_name);
        if(creep:IsAlive()) then
             local creep_hp = creep:GetHealth();
             if(lowest_hp > creep_hp) then
                 lowest_hp = creep_hp;
                 weakest_creep = creep;
             end
         end
    end

    if(weakest_creep ~= nil) then
        -- Last hitting
        if(DotaBotUtility.NilOrDead(npcBot:GetAttackTarget()) and 
        lowest_hp < npcBot:GetBaseDamageVariance( true, weakest_creep, 1.0, DAMAGE_TYPE_PHYSICAL + 20 ) and 
        weakest_creep:GetHealth() / weakest_creep:GetMaxHealth() < 0.5) then
            Attacking_creep = weakest_creep;
            npcBot:Action_AttackUnit(Attacking_creep,true);
            return;
        end
        weakest_creep = nil;
        
    end

    -- nothing to do , try to attack heroes

    local NearbyEnemyHeroes = npcBot:GetNearbyHeroes( 700, true, BOT_MODE_ATTACK );
    if(NearbyEnemyHeroes ~= nil) then
        for _,npcEnemy in pairs( NearbyEnemyHeroes )
        do
            if(DotaBotUtility.NilOrDead(npcBot:GetAttackTarget())) then
                npcBot:Action_AttackUnit(npcEnemy,false);
                return;
            end
        end
    end
    
end

local function ShouldRetreat()
    local npcBot = GetBot();
    return npcBot:GetHealth()/npcBot:GetMaxHealth() 
    < SlarkRetreatHPThreshold or npcBot:GetMana()/npcBot:GetMaxMana() 
    < SlarkRetreatMPThreshold;
end

local function IsTowerAttackingMe()
    local npcBot = GetBot();
    local NearbyTowers = npcBot:GetNearbyTowers(1000,true);
    if(#NearbyTowers > 0) then
        for _,tower in pairs( NearbyTowers)
        do
            if(GetUnitToUnitDistance(tower,npcBot) < 900 and tower:IsAlive()) then
                print("Attacked by tower");
                return true;
            end
        end
    else
        return false;
    end
end

-------------------local states-----------------------------------------------------

local function StateIdle(StateMachine)
    local npcBot = GetBot();
    if(npcBot:IsAlive() == false) then
        return;
    end

    local creeps = npcBot:GetNearbyCreeps(1000,true);
    local pt = DotaBotUtility:GetComfortPoint(creeps,LANE);

    

    if(ShouldRetreat()) then
        StateMachine.State = STATE_RETREAT;
        return;
    elseif(IsTowerAttackingMe()) then
        StateMachine.State = STATE_RUN_AWAY;
        return;
    elseif(npcBot:GetAttackTarget() ~= nil) then
        if(npcBot:GetAttackTarget():IsHero()) then
            StateMachine["EnemyToKill"] = npcBot:GetAttackTarget();
            print("auto attacking: "..npcBot:GetAttackTarget():GetUnitName());
            StateMachine.State = STATE_FIGHTING;
            return;
        end
    elseif(ConsiderFighting(StateMachine)) then
        StateMachine.State = STATE_FIGHTING;
        return;
    elseif(#creeps > 0 and pt ~= nil) then
        local mypos = npcBot:GetLocation();
        
        local d = GetUnitToLocationDistance(npcBot,pt);
        if(d > 250) then
            StateMachine.State = STATE_GOTO_COMFORT_POINT;
        else
            StateMachine.State = STATE_ATTACKING_CREEP;
        end
        return;
    end

    --target = GetLocationAlongLane(LANE,0.95);
    target = DotaBotUtility:GetNearBySuccessorPointOnLane(LANE);
    npcBot:Action_AttackMove(target);
    

end

local function StateAttackingCreep(StateMachine)
    local npcBot = GetBot();
    if(npcBot:IsAlive() == false) then
        StateMachine.State = STATE_IDLE;
        return;
    end

    local creeps = npcBot:GetNearbyCreeps(1000,true);
    local pt = DotaBotUtility:GetComfortPoint(creeps,LANE);

    if(ShouldRetreat()) then
        StateMachine.State = STATE_RETREAT;
        return;
    elseif(IsTowerAttackingMe()) then
        StateMachine.State = STATE_RUN_AWAY;
    elseif(ConsiderFighting(StateMachine)) then
        StateMachine.State = STATE_FIGHTING;
        return;
    elseif(#creeps > 0 and pt ~= nil) then
        local mypos = npcBot:GetLocation();
        local d = GetUnitToLocationDistance(npcBot,pt);
        if(d > 250) then
            StateMachine.State = STATE_GOTO_COMFORT_POINT;
        else
            ConsiderAttackCreeps();
        end
        return;
    else
        StateMachine.State = STATE_IDLE;
        return;
    end
end

local function StateRetreat(StateMachine)
    local npcBot = GetBot();
    if(npcBot:IsAlive() == false) then
        StateMachine.State = STATE_IDLE;
        return;
    end

    --[[
            I don't know how to Create a object of Location so I borrow one from GetLocation()
            Got Vector from marko.polo at http://dev.dota2.com/showthread.php?t=274301
    ]]
    npcBot:Action_MoveToLocation(Constant.HomePosition());

    if(npcBot:GetHealth() == npcBot:GetMaxHealth() and npcBot:GetMana() == npcBot:GetMaxMana()) then
        StateMachine.State = STATE_IDLE;
        return;
    end
end

local function StateGotoComfortPoint(StateMachine)
    local npcBot = GetBot();
    if(npcBot:IsAlive() == false) then
        StateMachine.State = STATE_IDLE;
        return;
    end

    local creeps = npcBot:GetNearbyCreeps(1000,true);
    local pt = DotaBotUtility:GetComfortPoint(creeps,LANE);
    

    if(ShouldRetreat()) then
        StateMachine.State = STATE_RETREAT;
        return;
    elseif(IsTowerAttackingMe()) then
        StateMachine.State = STATE_RUN_AWAY;
    elseif(ConsiderFighting(StateMachine)) then
        StateMachine.State = STATE_FIGHTING;
        return;
    elseif(#creeps > 0 and pt ~= nil) then
        local mypos = npcBot:GetLocation();
        --pt[3] = npcBot:GetLocation()[3];
        
        --local d = GetUnitToLocationDistance(npcBot,pt);
        local d = (npcBot:GetLocation() - pt):Length2D();
 
        if (d < 200) then
            StateMachine.State = STATE_ATTACKING_CREEP;
        else
            npcBot:Action_MoveToLocation(pt);
        end
        return;
    else
        StateMachine.State = STATE_IDLE;
        return;
    end

end

        -- Consider using each ability
        
        local castPounceDesire, castPounceTarget = ConsiderPounceFighting(abilityPounce,StateMachine["EnemyToKill"]);
        local castDarkDesire, castDark = ConsiderDarkPact(abilityDark,StateMachine["EnemyToKill"]);
        local castDanceDesire, castDance = ConsiderShadowDance(abilityDance);

        if ( castPounceDesire > 0 ) 
        then
            npcBot:Action_UseAbilityOnEntity( abilityPounce, castPounceTarget );
            return;
        end

        if ( castDarkDesire > 0 ) 
        then
            npcBot:Action_UseAbilityOnLocation( abilityDark, castDarkLocation );
            return;
        end

        if ( castDanceDesire > 0 ) 
        then
            npcBot:Action_UseAbilityOnLocation( abilityDance, castDanceLocation );
            return;
        end

        -- Pounce is castable but out of range, let's get closer
        if(abilityPounce:IsFullyCastable() and CanCastPounceOnTarget(StateMachine["EnemyToKill"])) then
            npcBot:Action_MoveToLocation(StateMachine["EnemyToKill"]:GetLocation());
                if (abilityDark:IsFullyCastable() and CanCastDarkOnTarget(StateMachine["EnemyToKill"])) then
            npcBot:Action_MoveToLocation(StateMachine["EnemyToKill"]:GetLocation());
            return;
            end
        end

        if(not abilityPounce:IsFullyCastable() and 
        not abilityPounce:IsFullyCastable() or StateMachine["EnemyToKill"]:IsMagicImmune()) then
            local extraHP = 0;
            if(abilityPounce:IsFullyCastable()) then
                local PouncenDamage = abilityPounce:GetSpecialValueInt( "pounce_damage" );
                local PounceeDamageType = DAMAGE_TYPE_MAGICAL;
                extraHP = StateMachine["EnemyToKill"]:GetActualDamage(PouncenDamage,PounceeDamageType);
            end

            if(StateMachine["EnemyToKill"]:GetHealth() - extraHP > npcBot:GetHealth()) then
                if(abilityDance:IsFullyCastable() ) 
                then npcBot:CanCastDance() 
                else
                    StateMachine.State = STATE_RUN_AWAY;
                    return;
                end
            end
        end


        if(npcBot:GetAttackTarget() ~= StateMachine["EnemyToKill"]) then
            npcBot:Action_AttackUnit(StateMachine["EnemyToKill"],false);
        end

local function StateRunAway(StateMachine)
    local npcBot = GetBot();

    if(npcBot:IsAlive() == false) then
        StateMachine.State = STATE_IDLE;
        StateMachine["RunAwayFromLocation"] = nil;
        return;
    end

    if(ShouldRetreat()) then
        StateMachine.State = STATE_RETREAT;
        StateMachine["RunAwayFromLocation"] = nil;
        return;
    end

    local mypos = npcBot:GetLocation();

    if(StateMachine["RunAwayFromLocation"] == nil) then
        --set the target to go back
        StateMachine["RunAwayFromLocation"] = npcBot:GetLocation();
        --npcBot:Action_MoveToLocation(Constant.HomePosition());
        npcBot:Action_MoveToLocation(DotaBotUtility:GetNearByPrecursorPointOnLane(LANE));
        return;
    else
        if(GetUnitToLocationDistance(npcBot,StateMachine["RunAwayFromLocation"]) > 400) then
            -- we are far enough from tower, return to normal state.
            StateMachine["RunAwayFromLocation"] = nil;
            StateMachine.State = STATE_IDLE;
            return;
        else
            npcBot:Action_MoveToLocation(DotaBotUtility:GetNearByPrecursorPointOnLane(LANE));
            return;
        end
    end
end 

local StateMachine = {};
StateMachine["State"] = STATE_IDLE;
StateMachine[STATE_IDLE] = StateIdle;
StateMachine[STATE_ATTACKING_CREEP] = StateAttackingCreep;
StateMachine[STATE_RETREAT] = StateRetreat;
StateMachine[STATE_GOTO_COMFORT_POINT] = StateGotoComfortPoint;
StateMachine[STATE_FIGHTING] = StateFighting;
StateMachine[STATE_RUN_AWAY] = StateRunAway;
StateMachine["totalLevelOfAbilities"] = 18;


local SlarkAbilityPriority = {"slark_dark_pact",
"slark_shadow_Dance","slark_pounce","slark_essence_shift"};

local SlarkTalents = {
    [10] = "special_bonus_lifesteal_10",
    [15] = "special_bonus_agility_15",
    [20] = "special_bonus_attack_speed_25",
    [25] = "special_bonus_all_stats_12"
};

local function ThinkLvlupAbility(StateMachine)
    -- Is there a bug? http://dev.dota2.com/showthread.php?t=274436
    local npcBot = GetBot();
    npcBot:Action_LevelAbility("slark_shadow_dance");
    npcBot:Action_LevelAbility("slark_dark_pact");
    npcBot:Action_LevelAbility("slark_pounce");
    npcBot:Action_LevelAbility("slark_essence_shift");
    for _,AbilityName in pairs(SlarkAbilityPriority)
    do
        if TryToUpgradeAbility(AbilityName) then
            break;
        end
    end
    --[[
        npcBot:Action_LevelAbility("slark_shadow_dance");
    npcBot:Action_LevelAbility("slark_dark_pact");
    npcBot:Action_LevelAbility("slark_pounce");
    npcBot:Action_LevelAbility("slark_essence_shift");
    ]]

    --[[
        for _,AbilityName in pairs(SlarkaAbilityPriority)
    do
        -- USELESS BREAK : because valve does not check ability points
        if TryToUpgradeAbility(AbilityName) then
            break;
        end
    end
    ]]   

    --npcBot:Action_LevelAbility("special_bonus_mp_250");

    local HeroLevel = PerryGetHeroLevel();

    if(SlarkaTalents[HeroLevel] ~= nil and StateMachine["totalLevelOfAbilities"] < HeroLevel) then
        npcBot:Action_LevelAbility(SlarkTalents[HeroLevel]);
        StateMachine["totalLevelOfAbilities"] = StateMachine["totalLevelOfAbilities"] + 1;
    else
        for k, ability_name in pairs(SlarkAbilityPriority) do
            local ability = npcBot:GetAbilityByName("slark_dark_pact");
            if (ability:CanAbilityBeUpgraded() and ability:GetLevel()<ability:GetMaxLevel() and StateMachine["totalLevelOfAbilities"] < HeroLevel) then
                ability:UpgradeAbility();
                StateMachine["totalLevelOfAbilities"] = StateMachine["totalLevelOfAbilities"] + 1;
                break;
            end
        end
    end
end

local PrevState = "none";

function Think(  )
    -- Think this item( ... )
    --update
    
    local npcBot = GetBot();
    DotaBotUtility:CourierThink();
    ThinkLvlupAbility(StateMachine);
    StateMachine[StateMachine.State](StateMachine);

    if(PrevState ~= StateMachine.State) then
        print("Slark bot STATE: "..StateMachine.State);
        PrevState = StateMachine.State;
    end
	
end