-- Runs VendorReagentFilter.lua against stubs of the WoW API.
-- Run from the repository root.

local MEAT, SPICE, FISH = 100, 2678, 200

local bags = {}
local schematics = {
	[1] = { { itemID = MEAT, quantity = 1 }, { itemID = SPICE, quantity = 1 } },
	[2] = { { itemID = FISH, quantity = 2 }, { itemID = SPICE, quantity = 1 } },
	[3] = { { itemID = SPICE, quantity = 1 } },
	[4] = { { itemID = MEAT, quantity = 1 } },
}

local loadedCallbacks = {}
local lastDataProvider
local menuCallback
local initCount = 0

EventUtil = {
	ContinueOnAddOnLoaded = function(name, callback)
		loadedCallbacks[name] = callback
	end,
}
Menu = {
	ModifyMenu = function(tag, callback)
		assert(tag == "MENU_PROFESSIONS_FILTER")
		menuCallback = callback
	end,
}
SlashCmdList = {}
hooksecurefunc = function(object, name, hook)
	local original = object[name]
	object[name] = function(...)
		original(...)
		hook(...)
	end
end
CopyTable = function(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = value
	end
	return copy
end
C_Item = {
	GetItemInfoInstant = function(item)
		return tonumber(item)
	end,
	GetItemNameByID = function()
		return nil
	end,
}
C_TradeSkillUI = {
	GetRecipeSchematic = function(recipeID)
		local slots = {}
		for _, reagent in ipairs(schematics[recipeID]) do
			slots[#slots + 1] = { reagents = { { itemID = reagent.itemID } }, quantityRequired = reagent.quantity, basicRequired = true }
		end
		return { reagentSlotSchematics = slots }
	end,
}
ProfessionsUtil = {
	IsReagentSlotBasicRequired = function(slot)
		return slot.basicRequired
	end,
	AccumulateReagentsInPossession = function(reagents)
		local total = 0
		for _, reagent in ipairs(reagents) do
			total = total + (bags[reagent.itemID] or 0)
		end
		return total
	end,
}

local function NewNode(data)
	local node = { data = data, nodes = {} }
	function node:GetNodes() return self.nodes end
	function node:GetData() return self.data end
	function node:IsCollapsed() return self.collapsed end
	function node:Insert(childData)
		local child = NewNode(childData)
		self.nodes[#self.nodes + 1] = child
		return child
	end
	function node:Remove(child)
		for index, other in ipairs(self.nodes) do
			if other == child then
				return table.remove(self.nodes, index)
			end
		end
	end
	return node
end

Professions = {
	GenerateCraftingDataProvider = function(_, _, _, collapses)
		collapses = collapses or {}
		local root = NewNode()
		local meat = root:Insert({ categoryInfo = { name = "Meat", categoryID = 1 } })
		meat:Insert({ topPadding = true })
		meat:Insert({ recipeInfo = { recipeID = 1, learned = true } })
		meat:Insert({ recipeInfo = { recipeID = 4, learned = false } })
		meat:Insert({ bottomPadding = true })
		local fish = root:Insert({ categoryInfo = { name = "Fish", categoryID = 2 } })
		fish.collapsed = collapses[2]
		fish:Insert({ topPadding = true })
		fish:Insert({ recipeInfo = { recipeID = 2, learned = true } })
		fish:Insert({ bottomPadding = true })
		local other = root:Insert({ categoryInfo = { name = "Other", categoryID = 3 } })
		other:Insert({ recipeInfo = { recipeID = 3, learned = true } })
		root:Insert({ isDivider = true })
		lastDataProvider = {
			invalidated = false,
			GetRootNode = function() return root end,
			Invalidate = function(self) self.invalidated = true end,
		}
		return lastDataProvider
	end,
}
ProfessionsFrame = {
	IsShown = function() return true end,
	CraftingPage = {
		professionInfo = {},
		RecipeList = { ScrollBox = {} },
		Init = function() initCount = initCount + 1 end,
		GetCollapses = function(self) return self.collapses end,
		StoreCollapses = function(self)
			self.collapses = {}
			for _, child in ipairs(lastDataProvider and lastDataProvider:GetRootNode():GetNodes() or {}) do
				if child.data.categoryInfo and child:IsCollapsed() then
					self.collapses[child.data.categoryInfo.categoryID] = true
				end
			end
		end,
	},
}

assert(loadfile("VendorReagentFilter.lua"))("VendorReagentFilter")
loadedCallbacks.VendorReagentFilter()
loadedCallbacks.Blizzard_ProfessionsTemplates()
loadedCallbacks.Blizzard_Professions()

local function RecipeIDs()
	local ids = {}
	local dataProvider = Professions.GenerateCraftingDataProvider()
	local function Walk(node)
		for _, child in ipairs(node:GetNodes()) do
			local data = child:GetData()
			if data.recipeInfo then
				ids[#ids + 1] = data.recipeInfo.recipeID
			end
			Walk(child)
		end
	end
	Walk(dataProvider:GetRootNode())
	table.sort(ids)
	return table.concat(ids, ","), dataProvider
end

local function Check(name, actual, expected)
	if actual ~= expected then
		error(("FAIL %s: expected %s, got %s"):format(name, tostring(expected), tostring(actual)))
	end
	print("PASS " .. name)
end

Check("default is off", VendorReagentFilterDB.enabled, false)
Check("filter off shows all recipes", (RecipeIDs()), "1,2,3,4")

CRAFT_IS_MAKEABLE = "Have Materials"
MenuUtil = {
	CreateCheckbox = function(text, isSelected, setSelected)
		return { text = text, isSelected = isSelected, setSelected = setSelected }
	end,
	GetElementText = function(elementDescription)
		return elementDescription.text
	end,
}
local elements = { { text = "Has skill up" }, { text = CRAFT_IS_MAKEABLE }, { text = "Slots" } }
menuCallback(nil, {
	EnumerateElementDescriptions = function()
		return ipairs(elements)
	end,
	Insert = function(_, description, index)
		table.insert(elements, index or #elements + 1, description)
	end,
})
local checkbox = elements[3]
Check("checkbox is after Have Materials", checkbox.text, "Have Materials (except vendor reagents)")
Check("Slots is last", elements[4].text, "Slots")
checkbox.setSelected()
Check("checkbox enables filter", checkbox.isSelected(), true)
Check("checkbox refreshes list", initCount, 1)

bags = {}
local ids, dataProvider = RecipeIDs()
Check("no materials: only vendor-only recipe", ids, "3")
Check("empty categories and divider removed", #dataProvider:GetRootNode():GetNodes(), 1)
Check("data provider invalidated", dataProvider.invalidated, true)

bags = { [MEAT] = 1 }
Check("meat without spice counts, unlearned does not", (RecipeIDs()), "1,3")

bags = { [MEAT] = 1, [FISH] = 1 }
Check("not enough fish", (RecipeIDs()), "1,3")

bags = { [MEAT] = 1, [FISH] = 2 }
Check("enough fish", (RecipeIDs()), "1,2,3")

local function CategoryNode(categoryID)
	for _, child in ipairs(lastDataProvider:GetRootNode():GetNodes()) do
		if child.data.categoryInfo and child.data.categoryInfo.categoryID == categoryID then
			return child
		end
	end
end

CategoryNode(2).collapsed = true
RecipeIDs()
Check("rebuild keeps a category collapsed", CategoryNode(2):IsCollapsed(), true)

bags = { [MEAT] = 1 }
Check("collapsed category removed by filter", (RecipeIDs()), "1,3")
Check("removed category is not in the list", CategoryNode(2), nil)
RecipeIDs()
Check("removed category stays in saved state", ProfessionsFrame.CraftingPage.collapses[2], true)

bags = { [MEAT] = 1, [FISH] = 2 }
RecipeIDs()
Check("returned category is collapsed", CategoryNode(2):IsCollapsed(), true)

CategoryNode(2).collapsed = false
RecipeIDs()
Check("rebuild keeps a category open", CategoryNode(2):IsCollapsed(), nil)

SlashCmdList.VENDORREAGENTFILTER("remove " .. SPICE)
Check("spice removed from vendor list", (RecipeIDs()), "")
SlashCmdList.VENDORREAGENTFILTER("add " .. SPICE)
Check("spice added to vendor list", (RecipeIDs()), "1,2,3")
SlashCmdList.VENDORREAGENTFILTER("bogus")
SlashCmdList.VENDORREAGENTFILTER("list")
print("ALL TESTS PASSED")
