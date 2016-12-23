

local tableItemsToBuy = { 
				"item_tango",
				"item_tango",
				"item_flask",
				"item_stout_shield",
				"item_slippers",
				"item_slippers",
				"item_boots",
				"item_boots_of_elves",
				"item_gloves",
				"item_ring_of_protection",
				"item_sobi_mask",
				"item_circlet",
				"item_slippers",
				"item_recipe_wraith_band",
				"item_shadow_amulet",
				"item_claymore",
				"item_sobi_mask",
				"item_quarterstaff",
				"item_robe",
				"item_orge_club",
				"item_recipe_silver_edge",
				"item_javelin",
				"item_belt_of_strength",
				"item_recipe_basher",
				"item_ultimate_orb",
				"item_ultimate_orb",
				"item_point_booster",
				"item_orb_of_venom",
			};


----------------------------------------------------------------------------------------------------

function ItemPurchaseThink()
    local npcBot = GetBot();
	if ( #tableItemsToBuy == 0 )
	then
		npcBot:SetNextItemPurchaseValue( 0 );
		return;
	end

	local sNextItem = tableItemsToBuy[1];
	

	npcBot:SetNextItemPurchaseValue( GetItemCost( sNextItem ) );

	if ( npcBot:GetGold() >= GetItemCost( sNextItem ) )
	then
		npcBot:Action_PurchaseItem( sNextItem );
		table.remove( tableItemsToBuy, 1 );
	end

end

----------------------------------------------------------------------------------------------------