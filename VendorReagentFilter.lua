local addonName = ...

local FILTER_LABEL = "Have Materials (except vendor reagents)"
local USAGE = "Usage: /vrf list | /vrf add <item link or ID> | /vrf remove <item link or ID>"

local DEFAULT_VENDOR_ITEMS = {
	[159] = true, -- Refreshing Spring Water
	[1179] = true, -- Ice Cold Milk
	[2596] = true, -- Skin of Dwarven Stout
	[2665] = true, -- Stormwind Seasoning Herbs
	[2678] = true, -- Mild Spices
	[2692] = true, -- Hot Spices
	[2894] = true, -- Rhapsody Malt
	[3713] = true, -- Soothing Spices
	[4536] = true, -- Shiny Red Apple
	[17194] = true, -- Holiday Spices
	[17196] = true, -- Holiday Spirits
	[30817] = true, -- Simple Flour
}

local function IsVendorSlot(reagentSlotSchematic)
	for _, reagent in ipairs(reagentSlotSchematic.reagents) do
		if reagent.itemID and VendorReagentFilterDB.items[reagent.itemID] then
			return true
		end
	end
	return false
end

local function CanCraftWithoutVendorReagents(recipeInfo)
	if not recipeInfo.learned then
		return false
	end

	local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeInfo.recipeID, false)
	for _, slot in ipairs(schematic.reagentSlotSchematics) do
		if ProfessionsUtil.IsReagentSlotBasicRequired(slot)
			and not IsVendorSlot(slot)
			and ProfessionsUtil.AccumulateReagentsInPossession(slot.reagents) < slot.quantityRequired then
			return false
		end
	end
	return true
end

-- The game saves the collapsed state only for categories that are in the list.
-- These are the collapsed categories that the filter removed from the list.
local prunedCollapsedCategories = {}

-- Removes recipes that fail the filter, then categories that have no recipes left.
local function PruneNode(node)
	local hasRecipe = false
	local children = node:GetNodes()
	for index = #children, 1, -1 do
		local child = children[index]
		local data = child:GetData()
		if data.recipeInfo then
			if CanCraftWithoutVendorReagents(data.recipeInfo) then
				hasRecipe = true
			else
				node:Remove(child, true)
			end
		elseif data.categoryInfo then
			if PruneNode(child) then
				hasRecipe = true
			else
				if child:IsCollapsed() then
					prunedCollapsedCategories[data.categoryInfo.categoryID] = true
				end
				node:Remove(child, true)
			end
		elseif data.isDivider then
			node:Remove(child, true)
		end
	end
	return hasRecipe
end

local function RefreshRecipeList()
	if ProfessionsFrame and ProfessionsFrame:IsShown() then
		local craftingPage = ProfessionsFrame.CraftingPage
		craftingPage:Init(craftingPage.professionInfo)
	end
end

EventUtil.ContinueOnAddOnLoaded(addonName, function()
	VendorReagentFilterDB = VendorReagentFilterDB or { enabled = false, items = CopyTable(DEFAULT_VENDOR_ITEMS) }
end)

EventUtil.ContinueOnAddOnLoaded("Blizzard_ProfessionsTemplates", function()
	local generateCraftingDataProvider = Professions.GenerateCraftingDataProvider
	local listIsSearchResult = false
	function Professions.GenerateCraftingDataProvider(professionID, searching, noStripCategories, collapses)
		-- The game saves the collapsed state only when the window closes, and each rebuild
		-- of the list uses that saved state. Save the state of the current list first.
		if ProfessionsFrame and not listIsSearchResult then
			local craftingPage = ProfessionsFrame.CraftingPage
			craftingPage:StoreCollapses(craftingPage.RecipeList.ScrollBox)
			collapses = craftingPage:GetCollapses()
		end
		listIsSearchResult = searching

		local dataProvider = generateCraftingDataProvider(professionID, searching, noStripCategories, collapses)
		prunedCollapsedCategories = {}
		if VendorReagentFilterDB.enabled then
			PruneNode(dataProvider:GetRootNode())
			dataProvider:Invalidate()
		end
		return dataProvider
	end
end)

EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", function()
	hooksecurefunc(ProfessionsFrame.CraftingPage, "StoreCollapses", function(craftingPage)
		for categoryID in pairs(prunedCollapsedCategories) do
			craftingPage.collapses[categoryID] = true
		end
	end)
end)

Menu.ModifyMenu("MENU_PROFESSIONS_FILTER", function(_, rootDescription)
	local checkbox = MenuUtil.CreateCheckbox(FILTER_LABEL, function()
		return VendorReagentFilterDB.enabled
	end, function()
		VendorReagentFilterDB.enabled = not VendorReagentFilterDB.enabled
		RefreshRecipeList()
	end)

	local indexAfterMakeable
	for index, elementDescription in rootDescription:EnumerateElementDescriptions() do
		if MenuUtil.GetElementText(elementDescription) == CRAFT_IS_MAKEABLE then
			indexAfterMakeable = index + 1
		end
	end
	rootDescription:Insert(checkbox, indexAfterMakeable)
end)

SLASH_VENDORREAGENTFILTER1 = "/vrf"
SlashCmdList.VENDORREAGENTFILTER = function(message)
	local command, item = message:match("^(%S+)%s*(.*)$")
	local items = VendorReagentFilterDB.items

	if command == "list" then
		for itemID in pairs(items) do
			print(itemID, C_Item.GetItemNameByID(itemID) or "(name not loaded)")
		end
		return
	end

	local itemID = (command == "add" or command == "remove") and C_Item.GetItemInfoInstant(item)
	if not itemID then
		print(USAGE)
		return
	end

	items[itemID] = command == "add" or nil
	print(("Vendor Reagent Filter: %s item %d."):format(command == "add" and "added" or "removed", itemID))
	RefreshRecipeList()
end
