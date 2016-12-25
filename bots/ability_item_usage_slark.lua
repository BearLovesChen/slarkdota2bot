
function AbilityUsageThink()

local npcBot = GetBot();

	local LocationMetaTable = getmetatable(npcBot:GetLocation());

    --[[
    for k,v in pairs(LocationMetaTable)
	do
	    print(k);
	end
	print("---------------------");
    
	--[[
	Length2D
	unm
	Dot
	Normalized
	Length
	Cross
	mul
	newindex
	len
	add
	eq
	sub
	div
	tostring
	index
	]]

	--print(npcBot:GetLocation()[1].." " .. npcBot:GetLocation()[2])

	local LocationAlongLaneMetatable = getmetatable(GetLocationAlongLane(3,2));

    for k,v in pairs(LocationAlongLaneMetatable)
	do
	    print(k);
	end
	print(GetLocationAlongLane(2,10));
	print("---------------------");

	-- Check if we're already using an ability
	if ( npcBot:IsUsingAbility() ) then return end;

	abilityDark = npcBot:GetAbilityByName( "slark_dark_pact" );
	abilityDance = npcBot:GetAbilityByName( "slark_shadow_dance" );
	abilityPounce = npcBot:GetAbilityByName( "slark_pounce" );

	-- Consider using each ability
	castPounceDesire, castPounceTarget = ConsiderPounce();
	castDarkDesire, castDarkLocation = ConsiderDarkPact();
	castDanceDesire, castDanceLocation = ConsiderShadowDance();

	if ( castPounceDesire > BOT_ACTION_DESIRE_NONE  ) 
	then
		npcBot:Action_UseAbilityOnEntity( abilityPounce, castPounceTarget );
		return;
	end

	if ( castDarkDesire > BOT_ACTION_DESIRE_NONE  ) 
	then
		npcBot:Action_UseAbility( abilityDark, castDark );
		return;
	end

	if ( castDanceDesire > BOT_ACTION_DESIRE_LOW ) 
	then
		npcBot:Action_UseAbility( abilityDance, castDance );
		return;
	end

	middle_point = npcBot:GetLocation();
	middle_point[1] = 0.0;
	middle_point[2] = 0.0;


	npcBot:Action_AttackMove(middle_point);

end

----------------------------------------------------------------------------------------------------

	-- Ability 1: Dark Pact ---
function ConsiderDarkPact()

	local npcBot = GetBot();

	-- Make sure we can cast it
	if ( not abilityDark:IsFullyCastable() )
	then
		return BOT_ACTION_DESIRE_NONE, 0;
	end;

	-- Get values for Dark Pact

	local nRadius = abilityDark:GetSpecialValueInt( "radius" );
	local nCastRange = abilityDark:GetCastRange();
	local nDamage = abilityDark:GetSpecialValueInt( "total_damage" );

	-- USAGE

	-- If farming
	if ( npcBot:GetActiveMode() == BOT_MODE_FARM ) then
		local locationAOE = npcBot:FindAOELocation( true, false, npcBot:getLocation(), nCastRange, nRadius, 0, nDamage );

		if ( locationAOE.count >= 3 ) then
			return BOT_ACTION_DESIRE_LOW, locationAOE.targetloc;
		end
	end

	-- If pushing a lane, farm creeps of 4 or more
	if ( npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP or
		 npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID or
		 npcBot:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOTTOM ) 
	then
		local locationAoE = npcBot:FindAoELocation( true, false, npcBot:GetLocation(), nCastRange, nRadius, 0, 0 );

		if ( locationAoE.count >= 4 ) 
		then
			return BOT_ACTION_DESIRE_LOW, locationAoE.targetloc;
		end
	end

	-- If tracked, x marked or dusted
	local npcBot = GetBot();
	if ( npcBot:HasModifier( modifier_bounty_hunter_track ) or
		 npcBot:HasModifier( modifier_kunkka_x_marks_the_spot ) or 
		 npcBot:HasModifier( modifier_item_dustofappearance ) )
		 then CanCastDark()
	end
end

	--- Ability 2: Pounce ---
function ConsiderPounce()

	local npcBot = GetBot();

	-- Is it castable?
	if ( not abilityPounce:IsFullyCastable() ) 
	then 
		return BOT_ACTION_DESIRE_NONE, 0;
	end;	

	-- Obtaining values
	local nDistance = AbilityPounce:GetSpecialValueInt( "pounce_distance" );
	local nLeashTime = AbilityPounce:GetSpecialValueInt( "leash_duration" );
	local nDamage = AbilityPounce:GetSpecialValueInt( "pounce_damage" );
	
	-- Kill the bastard
	local npcTarget = npcBot:GetTarget();
	if ( npcTarget ~= nil and CanCastPounceOnTarget( npcTarget ) and CanCastDark() )
	then
		if UnitToUnitDistance ( npcTarget, npcBot ) < ( nDistance  )
		then
			return BOT_ACTION_DESIRE_VERY_HIGH, npcTarget;
		end
	end

	-- If in teamfights

	local tableNearbyAttackingAlliedHeroes = NPCBot:GetNearbyHeroes( 1800, false, BOT_MODE_ATTACK )
	if ( #tableNearbyAttackingAlliedHeroes >=2 )
	then

		local npcMostDangerousEnemy = nil;
		local npcMostDangerousDamage = 0;

		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( nDistance, true, BOT_MODE_NONE );
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( CanCastDark () ) and ( CanCastPounceOnTarget ( npcEnemy ) )
			then
				local nDamage = npcEnemy:GetEstimatedDamageToTarget( false, npcBot, 3.0, DAMAGE_TYPE_ALL);
				if ( nDamage > nMostDangerousDamage )
				then
					nMostDangerousDamage = nDamage;
					npcMostDangerousEnemy = npcEnemy;
				end
			end
		end
	end
end

	-- If needing to escape
	local npcBot = GetBot();
	if ( ( ( npcBot:GetActiveMode() ) == BOT_MODE_RETREAT) and (npcBot:GetActiveModeDesire() == BOT_MODE_DESIRE_MEDIUM ) )
	then 
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1800, true, BOT_MODE_NONE );
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( npcBot:WasRecentlyDamagedByHero( npcEnemy, 1.0 ) ) 	
			then
				if ( CanCastPounce() )
				then
					return BOT_ACTION_DESIRE_MODERATE, npcEnemy:GetLocation();
				end
			end
		end
	end

	--- Ultimate: Shadow Dance ---

function ConsiderShadowDance()

	local npcBot = GetBot();

		-- Is it castable?
	if ( not abilityDance:IsFullyCastable() )
	then
		return BOT_ACTION_DESIRE_NONE, 0;
	end;

	-- If fighting

	if ( npcBot:GetActiveMode() == BOT_MODE_ROAM or
		 npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
		 npcBot:GetActiveMode() == BOT_MODE_GANK or
		 npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY and
	 	 npcBot:GetActiveModeDesire() == BOT_MODE_DESIRE_VERY_HIGH and
		 npcBot:GetHealth() < 150 )
		then 
			local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1800, true, BOT_MODE_NONE );
			for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
			do
				if ( npcBot:GetHealth() < 150 ) 
				then
					if ( CanCastShadowDance() )
					then
						return BOT_ACTION_DESIRE_ABSOLUTE, npcEnemy:GetLocation();
					end
				end
			end
		end
	end

	-- If needing to escape
	local npcBot = GetBot();
	if ( ( ( npcBot:GetActiveMode() ) == BOT_MODE_RETREAT) and (npcBot:GetActiveModeDesire() == BOT_MODE_DESIRE_MEDIUM ) )
	then 
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1800, true, BOT_MODE_NONE );
		for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
		do
			if ( npcBot:GetHealth() < 0.2 ) 
			then
				if CanCastShadowDance()
				then
					return BOT_ACTION_DESIRE_VERY_HIGH, npcEnemy:GetLocation();
				end
			end
		end
	end