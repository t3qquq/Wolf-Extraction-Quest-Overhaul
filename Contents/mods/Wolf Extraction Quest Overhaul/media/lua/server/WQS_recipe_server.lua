--[[ 
WQS_RecipeServer = {}
WQS_RecipeServer.GetItemTypes = {}

function WQS_RecipeServer.GetItemTypes.WQS_maps(scriptItems)
    scriptItems:addAll(getScriptManager():getItemsTag("wqs_map_item"));
end

--inv:containsTagRecurse(info.item) or inv:containsTypeRecurse(info.item)

 ]]