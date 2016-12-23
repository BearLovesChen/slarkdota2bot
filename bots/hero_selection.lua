

----------------------------------------------------------------------------------------------------

function Think()


	if ( GetTeam() == TEAM_RADIANT )
	then
		print( "selecting radiant" );
		SelectHero( 0, "npc_dota_hero_crystal_maiden" );
		SelectHero( 1, "npc_dota_hero_slark" );
		SelectHero( 2, "npc_dota_hero_bloodseeker" );
		SelectHero( 3, "npc_dota_hero_axe" );
		SelectHero( 4, "npc_dota_hero_bane" );
	elseif ( GetTeam() == TEAM_DIRE )
	then
		print( "selecting dire" );
		SelectHero( 5, "npc_dota_hero_drow_ranger" );
		SelectHero( 6, "npc_dota_hero_tidehunter" );
		SelectHero( 7, "npc_dota_hero_luna" );
		SelectHero( 8, "npc_dota_hero_oracle" );
		SelectHero( 9, "npc_dota_hero_witch_doctor" );
	end

end

----------------------------------------------------------------------------------------------------
