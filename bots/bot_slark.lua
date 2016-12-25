--[[
    StateMachine is a table
    the key "STATE" stores the STATE of Slark 
    other key value pairs: key is the string of state value is the function of the State. 

    Each frame DOTA2 will call Think()
    Then Think() will call the function of current state.
]]

local ValveAbilityUse = require(GetScriptDirectory().."\\ability_item_usage_slark");
local Constant = require(GetScriptDirectory().."\\constant_each_side");
local DotaBotUtility = require(GetScriptDirectory().."\\utility");

local STATE_IDLE = "STATE_IDLE";
local STATE_ATTACKING_CREEP = "STATE_ATTACKING_CREEP";
local STATE_KILL = "STATE_KILL";
local STATE_RETREAT = "STATE_RETREAT";
local STATE_FARMING = "STATE_FARMING";
local STATE_GOTO_COMFORT_POINT = "STATE_GOTO_COMFORT_POINT";
local STATE_FIGHTING = "STATE_FIGHTING";
local STATE_RUN_AWAY = "STATE_RUN_AWAY";

local SlarkRetreatHPThreshold = 0.15;
local SlarkRetreatMPThreshold = 0.05;

local STATE = STATE_IDLE;

LANE = LANE_BOT

-- Utility functions
-- Perry's code from http://dev.dota2.com/showthread.php?t=274837
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
                -- Enemy is hitting, kill the fucker!
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


local function ConsiderAttackCreeps(StateMachine)
    -- CREEPS?! HIT THEM BOY!
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
    
	local castDanceDesire, castDanceTarget = ConsiderShadowDance(abilityDance);
	local castPounceDesire, castPounce = ConsiderPounce(abilityPounce);
	local castDarkDesire, castDark = ConsiderDarkPact(abilityDark);

    if ( castPounceDesire > castDanceDesire and castPounceDesire > castDarkDesire ) 
	then
		npcBot:Action_UseAbilityOnEntity( abilityDance, castDanceTarget );
		return;
	end

	if ( castDanceDesire > 0 ) 
	then
		npcBot:Action_UseAbility( abilityDance, castDance );
		return;
	end

	if ( castDarkDesire > 0 ) 
	then
		npcBot:Action_UseAbility( abilityDark, castDark );
		return;
	end

    --print("desires: " .. castDanceDesire .. " " .. castPounceDesire .. " " .. castDarkDesire);

    --If we dont cast ability, just try to last hit...

    local lowest_hp = 100000;
    local weakest_creep = nil;
    for creep_k,creep in pairs(EnemyCreeps)
    do 
        --npcBot:GetBaseDamage
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

    if(weakest_creep ~= nil and weakest_creep:GetHealth() / weakest_creep:GetMaxHealth() < 0.5) then
        -- Let's try to last hit. Let's dream.
        --if(DotaBotUtility.NilOrDead(npcBot:GetAttackTarget()) and 
        if(lowest_hp < weakest_creep:GetActualDamage(
        npcBot:GetBaseDamage(),DAMAGE_TYPE_PHYSICAL)
        + DotaBotUtility:GetCreepHealthDeltaPerSec(weakest_creep) 
        * (npcBot:GetAttackPoint() / npcBot:GetAttackSpeed() 
        + GetUnitToUnitDistance(npcBot,weakest_creep) / 1000)) then
            if(npcBot:GetAttackTarget() == nil) then --StateMachine["attcking creep"]
                npcBot:Action_AttackUnit(weakest_creep,false);
                return;
            elseif(weakest_creep ~= StateMachine["attcking creep"]) then
                StateMachine["   creep"] = weakest_creep;
                npcBot:Action_AttackUnit(weakest_creep,true);
                return;
            end
        else
            -- Act human, Slark. Don't be a robot, you cuck. The attack, wait and go again motion.
            if(npcBot:GetCurrentActionType() == BOT_ACTION_TYPE_ATTACK) then
                npcBot:Action_ClearActions(true);
                return;
            else
                npcBot:Action_AttackUnit(weakest_creep,false);
                return;
            end
        end
        weakest_creep = nil;
        
    end

    for creep_k,creep in pairs(AllyCreeps)
    do 
        --npcBot:GetEstimatedDamageToTarget
        local creep_name = creep:GetUnitName();
        DotaBotUtility:UpdateCreepHealth(creep);
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
        -- Let's try to last hit. Let's dream.
        if(DotaBotUtility.NilOrDead(npcBot:GetAttackTarget()) and 
        lowest_hp < weakest_creep:GetActualDamage(
        npcBot:GetBaseDamage(),DAMAGE_TYPE_PHYSICAL) + DotaBotUtility:GetCreepHealthDeltaPerSec(weakest_creep) 
        * (npcBot:GetAttackPoint() / npcBot:GetAttackSpeed()
        + GetUnitToUnitDistance(npcBot,weakest_creep) / 1000)
         and 
        weakest_creep:GetHealth() / weakest_creep:GetMaxHealth() < 0.5) then
            Attacking_creep = weakest_creep;
            npcBot:Action_AttackUnit(Attacking_creep,true);
            return;
        end
        weakest_creep = nil;
        
    end

    -- Bored, hit heroes. Get them essenece shift procs my little fishy.

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

-------------------Local States-------------------

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
        local mypos = npcBot:Get();
        
        local d = GetUnitToDistance(npcBot,pt);
        if(d > 250) then
            StateMachine.State = STATE_GOTO_COMFORT_POINT;
        else
            StateMachine.State = STATE_ATTACKING_CREEP;
        end
        return;
    end

   -- Get a TP and be FREE! FREE MY SLARK, FREE!
    if(npcBot:DistanceFromFountain() < 100 and DotaTime() > 0) then
        local tpscroll = DotaBotUtility.IsItemAvailable("item_tpscroll");
        if(tpscroll == nil and DotaBotUtility:HasEmptySlot() and npcBot:GetGold() >= GetItemCost("item_tpscroll")) then
            print("buying tp");
            npcBot:Action_PurchaseItem("item_tpscroll");
            return;
        elseif(tpscroll ~= nil and tpscroll:IsFullyCastable()) then
            local tower = DotaBotUtility:GetFrontTowerAt(LANE);
            if(tower ~= nil) then
                npcBot:Action_UseAbilityOnEntity(tpscroll,tower);
                return;
            end
        end
    end
    

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
        local mypos = npcBot:Get();
        local d = GetUnitToDistance(npcBot,pt);
        if(d > 250) then
            StateMachine.State = STATE_GOTO_COMFORT_POINT;
        else
            ConsiderAttackCreeps();
        end
        return;
    else
        StateMachine.State = STATE_FARMING;
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
        Bear knowing how to create a location object. BrokeBack.
        Borrowed the vector from marko.polo at http://dev.dota2.com/showthread.php?t=274301
    ]]
    npcBot:Action_MoveTo(Constant.HomePosition());

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
        local mypos = npcBot:Get();
        --pt[3] = npcBot:Get()[3];
        
        --local d = GetUnitToDistance(npcBot,pt);
        local d = (npcBot:Get() - pt):Length2D();
 
        if (d < 200) then
            StateMachine.State = STATE_ATTACKING_CREEP;
        else
            npcBot:Action_MoveTo(pt);
        end
        return;
    else
        StateMachine.State = STATE_FARMING;
        return;
    end

end

local function StateFighting(StateMachine)
    local npcBot = GetBot();
    if(npcBot:IsAlive() == false) then
        StateMachine["dark pact time"] = nil;
        StateMachine.State = STATE_FIGHTING;
        return;
    end

    if(IsTowerAttackingMe()) then
        StateMachine["dark pact time"] = nil;
        StateMachine.State = STATE_RUN_AWAY;
    elseif(not StateMachine["EnemyToKill"]:CanBeSeen() or not StateMachine["EnemyToKill"]:IsAlive()) then
        -- lost enemy 
        print("lost enemy");
        StateMachine["dark pact time"] = nil;
        StateMachine.State = STATE_IDLE;
        return;
    else
        if ( npcBot:IsUsingAbility() ) then return end;

        local DarkPact = DotaBotUtility.IsCooldownReady("slark_dark_pact");

        if(DarkPact ~= nil) then
            if(ConsiderDarkPact(DarkPact,StateMachine["EnemyToKill"])) then
                npcBot:Action_UseAbility(DarkPact,StateMachine["EnemyToKill"]);
                StateMachine["dark pact time"] = GameTime();
                return;
            elseif(DarkPact:IsFullyCastable()) then
                -- Getting closer to Dark Pact then Pounce. Unf.
                npcBot:Action_MoveTo(StateMachine["EnemyToKill"]:Get());
                return;
            end
        end

        local abilityPounce = npcBot:GetAbilityByName( "slark_pounce" );
        local abilityDark = npcBot:GetAbilityByName( "slark_dark_pact" );
        local abilityDance = npcBot:GetAbilityByName( "slark_shadow_dance" );

        local Slark_DarkPact_Pounce_Combo_Delay = 1.4;

        if(StateMachine["dark pact time"] ~= nil) then
            -- Consider Pounce after DarkPact
            -- Cast Pounce 0.1s after DarkPact
            if(abilityPounce:IsFullyCastable() and GameTime() - StateMachine["dark pact time"] > Slark_DarkPact_Pounce_Combo_Delay) then
                if(DotaBotUtility.AbilityOutOfRange4Unit(abilityPounce,StateMachine["EnemyToKill"])) then
                    -- Let's get closer to Pounce. OOSH
                    npcBot:Action_MoveTo(StateMachine["EnemyToKill"]:Get());
                    return;
                else
                    npcBot:Action_UseAbility( abilityPounce, StateMachine["EnemyToKill"]:Get());
                    StateMachine["dark pact time"] = nil;
                    return;
                end
            elseif(abilityPounce:IsFullyCastable() and GameTime() - StateMachine["dark pact time"] < Slark_DarkPact_Pounce_Combo_Delay) then
                if(DotaBotUtility.AbilityOutOfRange4Unit(abilityPounce,StateMachine["EnemyToKill"])) then
                    -- Come on, get closer to you fuckwit.
                    npcBot:Action_MoveTo(StateMachine["EnemyToKill"]:Get());
                    return;
                end
            end
        end
        

        -- Consider using each ability
        
        local castDanceDesire, castDance = ConsiderShadowDance(abilityDance);
        local castPounceDesire, castPounceTarget = ConsiderPounceFighting(abilityPounce,StateMachine["EnemyToKill"]);
        local castDarkDesire, castDark = ConsiderDarkPactFighting(abilityDark,StateMachine["EnemyToKill"]);

        if ( castDanceDesire > 0 ) 
        then
            npcBot:Action_UseAbility( abilityDance, castDance );
            return;
        end

        if ( castPounceDesire > 0 ) 
        then
            npcBot:Action_UseAbilityOnEntity( abilityPounce, castPounceTarget );
            return;
        end

        if ( castDarkDesire > 0 ) 
        then
            npcBot:Action_UseAbility( abilityDark, castDark );
            return;
        end

        -- Pounce is ready! Let's go!
        if(abilityPounce:IsFullyCastable() and CanCastPounceOnTarget(StateMachine["EnemyToKill"])) then
            npcBot:Action_MoveTo(StateMachine["EnemyToKill"]:Get());
            return;
        end

        if(not abilityPounce:IsFullyCastable() and 
        not abilityDark:IsFullyCastable() or StateMachine["EnemyToKill"]:IsMagicImmune()) then
            local extraHP = 0;
            if(abilityDark:IsFullyCastable()) then
                local DarknDamage = abilityDark:GetSpecialValueInt( "total_damage" );
                extraHP = StateMachine["EnemyToKill"]:GetActualDamage(DarknDamage);
            end

            if(StateMachine["EnemyToKill"]:GetHealth() - extraHP > npcBot:GetHealth()) then
                StateMachine.State = STATE_RUN_AWAY;
                return;
            end
        end


        if(npcBot:GetAttackTarget() ~= StateMachine["EnemyToKill"]) then
            npcBot:Action_AttackUnit(StateMachine["EnemyToKill"],false);
        end

    end
end

local function StateRunAway(StateMachine)
    local npcBot = GetBot();

    if(npcBot:IsAlive() == false) then
        StateMachine.State = STATE_IDLE;
        StateMachine["RunAwayFrom"] = nil;
        return;
    end

    if(ShouldRetreat()) then
        StateMachine.State = STATE_RETREAT;
        StateMachine["RunAwayFrom"] = nil;
        return;
    end

    local mypos = npcBot:Get();

    if(StateMachine["RunAwayFrom"] == nil) then
        -- Run fishy run!
        StateMachine["RunAwayFrom"] = npcBot:Get();
        --npcBot:Action_MoveTo(Constant.HomePosition());
        npcBot:Action_MoveTo(DotaBotUtility:GetNearByPrecursorPointOnLane(LANE));
        return;
    else
        if(GetUnitToDistance(npcBot,StateMachine["RunAwayFrom"]) > 400) then
            -- We're safe, back we go to being a Slark.
            StateMachine["RunAwayFrom"] = nil;
            StateMachine.State = STATE_IDLE;
            return;
        else
            npcBot:Action_MoveTo(DotaBotUtility:GetNearByPrecursorPointOnLane(LANE));
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
StateMachine["totalLevelOfAbilities"] = 0;

local SlarkAbilityMap = {
    [1] = "slark_dark_pact",
    [2] = "slark_pounce",
    [3] = "slark_dark_pact",
    [4] = "slark_essence_shift",
    [5] = "slark_dark_pact",
    [6] = "slark_shadow_dance",
    [7] = "slark_dark_pact",
    [8] = "slark_pounce",
    [9] = "slark_pounce",
    [10] = "special_bonus_lifesteal_10",
    [11] = "slark_pouncet",
    [12] = "slark_shadow_dance",
    [13] = "slark_essence_shift",
    [14] = "slark_essence_shift",
    [15] = "special_bonus_agility_15",
    [16] = "slark_essence_shift",
    [18] = "slark_shadow_dance",
    [20] = "special_bonus_attack_speed_25", 
    [25] = "special_bonus_all_stats_12",
};

local SlarkDoneLvlupAbility = {};

for lvl,_ in pairs(SlarkAbilityMap)
do
    SlarkDoneLvlupAbility[lvl] = false;
end

local function ThinkLvlupAbility(StateMachine)
    -- Bug? http://dev.dota2.com/showthread.php?t=274436
local npcBot = GetBot();

    local HeroLevel = PerryGetHeroLevel();
    if(SlarkDoneLvlupAbility[HeroLevel] == false) then
        npcBot:Action_LevelAbility(SlarkAbilityMap[HeroLevel]);
        --SlarkDoneLvlupAbility[HeroLevel] = true;
    end
end

local PrevState = "none";

function Think(  )
    -- Think this item( ... )
    -- update
    
    local npcBot = GetBot();
    DotaBotUtility:CourierThink();
    ThinkLvlupAbility(StateMachine);
    StateMachine[StateMachine.State](StateMachine);

    if(PrevState ~= StateMachine.State) then
        print("Slark bot STATE: "..StateMachine.State);
        PrevState = StateMachine.State;
    end
	
end