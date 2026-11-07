' Polls the Ficsit Remote Monitoring API on a background thread and
' publishes a compact summary to m.top.result for the UI to render.

sub init()
    m.top.functionName = "run"
end sub

sub run()
    port = CreateObject("roMessagePort")
    m.top.observeField("refreshNow", port)
    m.top.observeField("baseUrl", port)
    base = m.top.baseUrl
    slow = {}
    tick = 0
    recipeDb = invalid
    while true
        if m.top.baseUrl <> base
            ' Server changed: drop everything from the old one
            base = m.top.baseUrl
            slow = {}
            tick = 0
            recipeDb = invalid
        end if
        out = { ok: false, base: base }
        session = getJson(base + "/getSessionInfo")
        if session <> invalid
            out.ok = true
            out.session = summarizeSession(session)
            out.power = summarizePower(getJson(base + "/getPower"))
            out.prod = summarizeProd(getJson(base + "/getProdStats"))
            ' Elevator is small and drives the "ready" alert, so poll it fast
            out.elevator = summarizeElevator(getJson(base + "/getSpaceElevator"))
            ' Heavier / slower-changing data every 4th cycle
            if tick MOD 4 = 0
                slow.factory = summarizeMachines(getJson(base + "/getFactory"), getJson(base + "/getExtractor"))
                slow.generators = summarizeGenerators(getJson(base + "/getGenerators"))
                slow.sink = summarizeSink(getJson(base + "/getResourceSink"))
                slow.inv = {
                    storage: containerTotals(getJson(base + "/getStorageInv")),
                    cloud: itemTotals(getJson(base + "/getCloudInv"))
                }
            end if
            ' HUB is small and carries the pod countdown, so poll it every cycle
            hub = summarizeHub(getJson(base + "/getHUBTerminal"))
            if hub <> invalid then slow.hub = hub
            ' World totals are small and feed the TOTAL column, so refresh every cycle
            w = getJson(base + "/getWorldInv")
            if w <> invalid then slow.inv.world = itemTotals(w)
            ' Recipe book (~580 KB): load once, then every ~10 minutes
            if recipeDb = invalid or tick MOD 120 = 0
                db = buildRecipeDb(getJson(base + "/getRecipes"))
                if db <> invalid then recipeDb = db
            end if
            out.append(slow)
            out.recipes = recipesFor(recipeDb, slow.hub, out.elevator, slow.factory)
            tick = tick + 1
        else
            tick = 0 ' refetch slow data as soon as we reconnect
            code = m.lastCode
            if code = 200 then out.errKind = "notfrm" else out.errKind = classifyFailure(code)
            out.errCode = code
        end if
        dt = CreateObject("roDateTime")
        dt.ToLocalTime()
        out.time = pad2(dt.GetHours()) + ":" + pad2(dt.GetMinutes()) + ":" + pad2(dt.GetSeconds())
        m.top.result = out
        wait(m.top.interval * 1000, port) ' returns early on refreshNow
    end while
end sub

function getJson(url as String) as Dynamic
    r = httpGet(url, 8000)
    m.lastCode = r.code
    if r.code = 200 then return ParseJson(r.body)
    return invalid
end function

function num(v as Dynamic) as Float
    if v = invalid then return 0
    t = type(v)
    if t = "roFloat" or t = "Float" or t = "roInt" or t = "Integer" or t = "roDouble" or t = "Double" or t = "LongInteger" or t = "roLongInteger" then return v
    return 0
end function

function pad2(n as Integer) as String
    if n < 10 then return "0" + n.ToStr()
    return n.ToStr()
end function

function summarizeSession(s as Object) as Object
    return {
        name: s.SessionName, paused: s.IsPaused = true, isDay: s.IsDay = true,
        day: Int(num(s.PassedDays)), clock: pad2(Int(num(s.Hours))) + ":" + pad2(Int(num(s.Minutes))),
        played: s.TotalPlayDurationText
    }
end function

function summarizePower(a as Dynamic) as Dynamic
    if type(a) <> "roArray" then return invalid
    r = { prod: 0.0, cons: 0.0, cap: 0.0, peak: 0.0, batCap: 0.0, batStored: 0.0, batIn: 0.0, batOut: 0.0, fuse: false, circuits: a.Count(), list: [] }
    for each c in a
        r.list.push({ id: Int(num(c.CircuitGroupID)), prod: num(c.PowerProduction), cons: num(c.PowerConsumed), cap: num(c.PowerCapacity), fuse: c.FuseTriggered = true })
        r.prod = r.prod + num(c.PowerProduction)
        r.cons = r.cons + num(c.PowerConsumed)
        r.cap = r.cap + num(c.PowerCapacity)
        r.peak = r.peak + num(c.PowerMaxConsumed)
        bc = num(c.BatteryCapacity)
        r.batCap = r.batCap + bc
        r.batStored = r.batStored + bc * num(c.BatteryPercent) / 100
        r.batIn = r.batIn + num(c.BatteryInput)
        r.batOut = r.batOut + num(c.BatteryOutput)
        if c.FuseTriggered = true then r.fuse = true
    end for
    return r
end function

function summarizeProd(a as Dynamic) as Dynamic
    if type(a) <> "roArray" then return invalid
    rows = []
    for each it in a
        p = num(it.CurrentProd)
        c = num(it.CurrentConsumed)
        if p > 0.01 or c > 0.01 then rows.push({ name: it.Name, prod: p, cons: c, maxProd: num(it.MaxProd), maxCons: num(it.MaxConsumed) })
    end for
    rows.SortBy("name", "i")
    return rows
end function

function summarizeMachines(fac as Dynamic, ext as Dynamic) as Dynamic
    if type(fac) <> "roArray" then return invalid
    acc = {
        r: { total: fac.Count(), running: 0, idle: 0, paused: 0, eff: 0.0, extractors: 0, extRunning: 0 },
        types: {}, recipes: {}, cons: {}, prods: {}, idle: [], effSum: 0.0, effN: 0, inUse: {}
    }
    for each b in fac
        addMachine(b, false, acc)
    end for
    if type(ext) = "roArray"
        for each b in ext
            addMachine(b, true, acc)
        end for
    end if
    r = acc.r
    if acc.effN > 0 then r.eff = acc.effSum / acc.effN
    r.types = sortedValues(acc.types, "count")
    running = sortedValues(acc.recipes, "count")
    for each e in running
        e.eff = e.effSum / e.count
    end for
    r.running_list = running
    r.consumers = sortedValues(acc.cons, "cur")
    r.idle_list = acc.idle
    r.inUse = acc.inUse
    r.producers = {}
    for each k in acc.prods
        e = acc.prods[k]
        r.producers[e.item] = sortedValues(e.m, "count")
    end for
    return r
end function

sub addMachine(b as Object, isExt as Boolean, acc as Object)
    r = acc.r
    name = b.Name
    if name = invalid then name = "?"
    producing = b.IsProducing = true and b.IsPaused <> true
    if isExt
        r.extractors = r.extractors + 1
        if producing then r.extRunning = r.extRunning + 1
    else if b.IsPaused = true
        r.paused = r.paused + 1
    else if producing
        r.running = r.running + 1
    else
        r.idle = r.idle + 1
    end if
    if not isExt and b.IsConfigured = true and b.IsPaused <> true
        acc.effSum = acc.effSum + num(b.Productivity)
        acc.effN = acc.effN + 1
    end if

    if b.RecipeClassName <> invalid then acc.inUse[b.RecipeClassName] = true
    if not acc.types.DoesExist(name) then acc.types[name] = { name: name, count: 0, running: 0, ext: isExt }
    t = acc.types[name]
    t.count = t.count + 1
    if producing then t.running = t.running + 1

    recipe = b.Recipe
    if recipe = invalid or recipe = "" then recipe = "No recipe"
    if producing
        key = recipe + " (" + name + ")"
        if not acc.recipes.DoesExist(key) then acc.recipes[key] = { name: key, count: 0, effSum: 0.0 }
        e = acc.recipes[key]
        e.count = e.count + 1
        e.effSum = e.effSum + num(b.Productivity)
    else if acc.idle.Count() < 40
        acc.idle.push({ name: name + " - " + recipe, reason: idleReason(b, isExt) })
    end if

    if b.PowerInfo <> invalid
        if not acc.cons.DoesExist(name) then acc.cons[name] = { name: name, count: 0, cur: 0.0, max: 0.0 }
        c = acc.cons[name]
        c.count = c.count + 1
        c.cur = c.cur + num(b.PowerInfo.PowerConsumed)
        c.max = c.max + num(b.PowerInfo.MaxPowerConsumed)
    end if

    if b.IsConfigured <> false and type(b.production) = "roArray"
        for each p in b.production
            item = p.Name
            if item <> invalid
                if not acc.prods.DoesExist(item) then acc.prods[item] = { item: item, m: {} }
                pm = acc.prods[item].m
                if not pm.DoesExist(name) then pm[name] = { name: name, count: 0 }
                pm[name].count = pm[name].count + 1
            end if
        end for
    end if
end sub

function idleReason(b as Object, isExt as Boolean) as String
    if b.IsPaused = true then return "Paused"
    if not isExt and b.IsConfigured <> true then return "No recipe"
    if invFull(b.OutputInventory) then return "Output full"
    if not isExt
        inp = b.InputInventory
        if type(inp) <> "roArray" or inp.Count() = 0 then return "Missing input"
        for each it in inp
            if num(it.Amount) <= 0 then return "Missing input"
        end for
    end if
    return "Waiting"
end function

function invFull(inv as Dynamic) as Boolean
    if type(inv) <> "roArray" then return false
    for each it in inv
        mx = num(it.MaxAmount)
        if mx > 0 and num(it.Amount) >= mx * 0.95 then return true
    end for
    return false
end function

' Converts an AA of AAs into an array sorted (descending) by field
function sortedValues(aa as Object, field as String) as Object
    arr = []
    for each k in aa
        arr.push(aa[k])
    end for
    arr.SortBy(field, "r")
    return arr
end function

function summarizeGenerators(a as Dynamic) as Dynamic
    if type(a) <> "roArray" then return invalid
    map = {}
    for each g in a
        n = g.Name
        if not map.DoesExist(n) then map[n] = { name: n, count: 0, cap: 0.0, out: 0.0 }
        e = map[n]
        cap = num(g.ProductionCapacity)
        e.count = e.count + 1
        e.cap = e.cap + cap
        e.out = e.out + cap * num(g.LoadPercentage) / 100
    end for
    return sortedValues(map, "cap")
end function

function itemTotals(a as Dynamic) as Object
    t = {}
    if type(a) <> "roArray" then return t
    for each it in a
        if it.Name <> invalid then t[it.Name] = num(t[it.Name]) + num(it.Amount)
    end for
    return t
end function

function containerTotals(a as Dynamic) as Object
    t = {}
    if type(a) <> "roArray" then return t
    for each c in a
        if type(c.Inventory) = "roArray"
            for each it in c.Inventory
                if it.Name <> invalid then t[it.Name] = num(t[it.Name]) + num(it.Amount)
            end for
        end if
    end for
    t["__containers"] = a.Count()
    return t
end function

function costRows(list as Dynamic) as Object
    rows = []
    if type(list) <> "roArray" then return rows
    for each c in list
        total = num(c.TotalCost)
        rows.push({ name: c.Name, done: total - num(c.RemainingCost), total: total })
    end for
    return rows
end function

function summarizeHub(a as Dynamic) as Dynamic
    if type(a) <> "roArray" or a.Count() = 0 then return invalid
    h = a[0]
    pod = { secs: hmsToSecs(h.ShipReturn), docked: h.ShipDock = true }
    if h.HasActiveMilestone <> true or h.ActiveMilestone = invalid then return { active: false, pod: pod }
    ms = h.ActiveMilestone
    unlocks = []
    if type(ms.Recipes) = "roArray"
        for each rc in ms.Recipes
            unlocks.push(rc.Name)
        end for
    end if
    return { active: true, name: ms.Name, tier: Int(num(ms.TechTier)), cost: costRows(ms.Cost), unlocks: unlocks, pod: pod }
end function

' "HH:MM:SS" -> seconds
function hmsToSecs(t as Dynamic) as Integer
    if type(t) <> "roString" and type(t) <> "String" then return 0
    parts = t.Split(":")
    total = 0
    for each p in parts
        total = total * 60 + Int(Val(p))
    end for
    return total
end function

function summarizeElevator(a as Dynamic) as Dynamic
    if type(a) <> "roArray" or a.Count() = 0 then return invalid
    e = a[0]
    return { full: e.FullyUpgraded = true, ready: e.UpgradeReady = true, cost: costRows(e.CurrentPhase) }
end function

function summarizeSink(a as Dynamic) as Dynamic
    if type(a) <> "roArray" or a.Count() = 0 then return invalid
    s = a[0]
    return { coupons: Int(num(s.NumCoupon)), percent: num(s.Percent), points: num(s.TotalPoints), toNext: num(s.PointsToCoupon) }
end function

' ---------- Recipes ----------

' item name -> array of factory recipes that make it as their main product
function buildRecipeDb(a as Dynamic) as Dynamic
    if type(a) <> "roArray" then return invalid
    db = {}
    for each r in a
        building = factoryBuilding(r.ProducedIn)
        if building <> "" and type(r.Products) = "roArray" and r.Products.Count() > 0 and type(r.Ingredients) = "roArray"
            item = r.Products[0].Name
            ing = []
            for each i in r.Ingredients
                ing.push({ name: i.Name, amount: num(i.Amount) })
            end for
            if not db.DoesExist(item) then db[item] = []
            db[item].push({
                name: r.Name, cls: r.ClassName, alt: Instr(1, r.ClassName, "Alternate") > 0,
                building: building, out: num(r.Products[0].Amount), ing: ing
            })
        end if
    end for
    return db
end function

function factoryBuilding(producedIn as Dynamic) as String
    if type(producedIn) <> "roArray" then return ""
    names = {
        Build_ConstructorMk1_C: "Constructor", Build_AssemblerMk1_C: "Assembler", Build_ManufacturerMk1_C: "Manufacturer",
        Build_SmelterMk1_C: "Smelter", Build_FoundryMk1_C: "Foundry", Build_OilRefinery_C: "Refinery",
        Build_Packager_C: "Packager", Build_Blender_C: "Blender", Build_HadronCollider_C: "Particle Accelerator",
        Build_Converter_C: "Converter", Build_QuantumEncoder_C: "Quantum Encoder"
    }
    for each p in producedIn
        if Left(p, 6) = "Build_"
            if names.DoesExist(p) then return names[p]
            n = Mid(p, 7)
            if Right(n, 2) = "_C" then n = Left(n, Len(n) - 2)
            return n
        end if
    end for
    return ""
end function

' Recipes for milestone + elevator parts: alternates the factory is running
' (marked inUse) first, then the standard recipe. At most 2 per item.
function recipesFor(db as Dynamic, hub as Dynamic, elev as Dynamic, fac as Dynamic) as Object
    out = {}
    if db = invalid then return out
    inUse = {}
    if fac <> invalid and fac.inUse <> invalid then inUse = fac.inUse
    items = []
    if hub <> invalid and hub.cost <> invalid then items.append(hub.cost)
    if elev <> invalid and elev.cost <> invalid then items.append(elev.cost)
    for each c in items
        list = db[c.name]
        if list <> invalid
            picked = []
            hasStd = false
            for each r in list
                if inUse.DoesExist(r.cls) and picked.Count() < 2
                    rr = {}
                    rr.append(r)
                    rr.inUse = true
                    picked.push(rr)
                    if not r.alt then hasStd = true
                end if
            end for
            if not hasStd and picked.Count() < 2
                for each r in list
                    if not r.alt
                        picked.push(r)
                        exit for
                    end if
                end for
            end if
            out[c.name] = picked
        end if
    end for
    return out
end function
