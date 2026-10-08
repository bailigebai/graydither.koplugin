local ok, Settings=pcall(require,"graydither.refreshsettings")
assert(ok,"Refresh settings feature is missing: "..tostring(Settings))
local function store(data)
    return {data=data or {},readSetting=function(self,k)return self.data[k]end,
        saveSetting=function(self,k,v)self.data[k]=v end}
end

test("refresh defaults leave automatic off with usable manual options",function()
    local prefs=Settings.new(store())
    eq(prefs:getEnabled(),false);eq(prefs:getInterval(),5)
    eq(prefs:getMode(),"native");eq(prefs:getHold(),0.30)
end)

test("disabling and enabling preserves selected interval and existing reader settings",function()
    local gs=store({full_refresh_count=8,eink_refresh_interval=3})
    local prefs=Settings.new(gs);prefs:setInterval(7);prefs:setEnabled(true)
    prefs:setEnabled(false);prefs:setEnabled(true)
    eq(prefs:getEnabled(),true);eq(prefs:getInterval(),7)
    eq(gs.data.full_refresh_count,8);eq(gs.data.eink_refresh_interval,3)
end)

test("invalid saved refresh options use bounded defaults",function()
    for _,bad in ipairs({0,-1,51,2.5,"3",true,{},math.huge,0/0}) do
        eq(Settings.new(store({graydither_refresh_interval=bad})):getInterval(),5)
    end
    for _,bad in ipairs({0,0.09,1.01,"0.30",true,{},math.huge,0/0}) do
        eq(Settings.new(store({graydither_refresh_hold=bad})):getHold(),0.30)
    end
    for _,bad in ipairs({"true",1,{},"flash"}) do
        eq(Settings.new(store({graydither_refresh_enabled=bad})):getEnabled(),false)
    end
    for _,bad in ipairs({false,1,"unknown",{}}) do
        eq(Settings.new(store({graydither_refresh_mode=bad})):getMode(),"native")
    end
end)

test("refresh boundaries persist in host settings",function()
    local gs=store();local prefs=Settings.new(gs)
    for _,iv in ipairs({1,50}) do prefs:setInterval(iv);eq(prefs:getInterval(),iv) end
    for _,hold in ipairs({0.10,1.00}) do prefs:setHold(hold);eq(prefs:getHold(),hold) end
    prefs:setMode("flash");eq(prefs:getMode(),"flash")
    local reopened=Settings.new(gs)
    eq(reopened:getInterval(),50);eq(reopened:getHold(),1.00);eq(reopened:getMode(),"flash")
end)

test("invalid refresh writes do not persist",function()
    local gs=store();local prefs=Settings.new(gs)
    for _,bad in ipairs({0,51,2.5,"5",math.huge,0/0}) do
        eq(pcall(function()prefs:setInterval(bad)end),false)
    end
    for _,bad in ipairs({0,1.01,"0.30",math.huge,0/0}) do
        eq(pcall(function()prefs:setHold(bad)end),false)
    end
    eq(pcall(function()prefs:setMode("unknown")end),false)
    eq(pcall(function()prefs:setEnabled(1)end),false)
    eq(next(gs.data),nil)
end)
