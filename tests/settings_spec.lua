local ok,Settings=pcall(require,"graydither.settings")
assert(ok,"Settings is not implemented yet")
local function store(data)
    return {
        data=data or {},
        readSetting=function(self,key)return self.data[key]end,
        saveSetting=function(self,key,value)self.data[key]=value end,
        delSetting=function(self,key)self.data[key]=nil end,
    }
end
test("global disabled plus document true enables processing",function()
    local prefs=Settings.new(store({graydither_enabled=false}),store({graydither_enabled=true}))
    eq(prefs:isEnabled(),true)
end)
test("document false overrides enabled global",function()
    local prefs=Settings.new(store({graydither_enabled=true}),store({graydither_enabled=false}))
    eq(prefs:isEnabled(),false)
end)
test("nil document follows global and default is disabled",function()
    local global=store();local doc=store();local prefs=Settings.new(global,doc)
    eq(prefs:isEnabled(),false);prefs:setGlobal(true);eq(prefs:isEnabled(),true)
    prefs:setOverride(false);eq(prefs:isEnabled(),false)
    prefs:setOverride(nil);eq(prefs:getOverride(),nil);eq(prefs:isEnabled(),true)
end)
test("invalid stored values do not accidentally enable processing",function()
    for _,v in ipairs({"true",1,{},0}) do
        local prefs=Settings.new(store({graydither_enabled=v}),store({graydither_enabled=v}))
        eq(prefs:getOverride(),nil);eq(prefs:isEnabled(),false)
    end
end)
test("only namespaced preference is modified",function()
    local global=store({unrelated="preserve"});local doc=store({other="unchanged"})
    local prefs=Settings.new(global,doc);prefs:setGlobal(true);prefs:setOverride(false)
    eq(global.data.unrelated,"preserve");eq(doc.data.other,"unchanged")
    eq(global.data.graydither_enabled,true);eq(doc.data.graydither_enabled,false)
end)
test("invalid API values are rejected without saving",function()
    local g=store();local d=store();local prefs=Settings.new(g,d)
    eq(pcall(function()prefs:setGlobal("true")end),false)
    eq(pcall(function()prefs:setOverride(1)end),false)
    eq(next(g.data),nil);eq(next(d.data),nil)
end)

