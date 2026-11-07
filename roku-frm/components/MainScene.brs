' Factory dashboard layout (1920x1080) with D-pad focus + tooltips.

sub init()
    m.C = {
        text: "0xE6E8ECFF", dim: "0x8A93A3FF", accent: "0xFA9549FF",
        card: "0x181B22FF", track: "0x2A2F3AFF", tipBg: "0x232833FF",
        good: "0x4CC38AFF", warn: "0xF2C94CFF", bad: "0xEB5757FF"
    }
    m.PROD_ROWS = 14
    m.data = invalid
    m.prodOffset = 0
    m.prodByName = {}
    m.targets = []
    m.focus = invalid
    m.focusVisible = false
    m.seWasReady = invalid
    m.seShowingReady = false
    m.demo = false
    m.MAX_PINS = 5
    m.pins = loadPins()
    m.prodView = invalid
    m.prodPinned = 0
    m.prodRest = 0
    ui = m.top.findNode("ui")
    C = m.C

    ' ---------- Header ----------
    hdr = ui.createChild("Rectangle")
    hdr.width = 1920 : hdr.height = 110 : hdr.color = "0x14171DFF"
    acc = ui.createChild("Rectangle")
    acc.translation = [0, 106] : acc.width = 1920 : acc.height = 4 : acc.color = C.accent
    lbl(ui, 60, 18, 0, 46, true, C.accent, "", "FACTORY DASHBOARD")
    m.session = lbl(ui, 62, 68, 900, 28, false, C.dim, "", "")
    m.status = lbl(ui, 1060, 16, 800, 40, true, C.dim, "right", "CONNECTING")
    m.clock = lbl(ui, 1060, 64, 800, 28, false, C.dim, "right", "")

    ' ---------- Power ----------
    card(ui, 60, 140, 870, 330, "POWER")
    m.circuits = lbl(ui, 500, 158, 400, 26, false, C.dim, "right", "")
    m.pw = {}
    tiles = [["prod", "PRODUCING"], ["cons", "CONSUMING"], ["cap", "CAPACITY"], ["peak", "PEAK DEMAND"]]
    for i = 0 to 3
        x = 90 + i * 205
        lbl(ui, x, 205, 200, 22, false, C.dim, "", tiles[i][1])
        m.pw[tiles[i][0]] = lbl(ui, x, 232, 200, 50, true, C.text, "", "-")
        addTarget("pw_" + tiles[i][0], x - 8, 198, 196, 96, "power", i)
    end for
    lbl(ui, 90, 290, 0, 22, false, C.dim, "", "MW")
    m.loadBar = bar(ui, 90, 330, 810, 22)
    m.loadText = lbl(ui, 90, 365, 810, 26, false, C.text, "", "")
    m.battery = lbl(ui, 90, 410, 810, 26, false, C.dim, "", "")
    addTarget("pw_load", 82, 322, 826, 124, "power", 4)

    ' ---------- Milestone ----------
    card(ui, 60, 500, 870, 320, "MILESTONE")
    m.msTier = lbl(ui, 280, 520, 200, 26, false, C.dim, "", "")
    m.podLabel = lbl(ui, 480, 518, 420, 26, true, C.dim, "right", "")
    m.podSecs = -1          ' countdown from the mod (0 = not reported)
    m.podAway = invalid     ' from ShipDock; invalid until first reading
    m.podElapsed = -1       ' game-seconds since we saw the pod leave (-1 = unknown)
    m.podTier = -1
    m.lastTier = -1
    m.gamePaused = false
    m.podTimer = m.top.createChild("Timer")
    m.podTimer.duration = 1
    m.podTimer.repeat = true
    m.podTimer.observeField("fire", "onPodTick")
    m.podTimer.control = "start"
    m.msName = lbl(ui, 90, 552, 810, 40, true, C.text, "", "-")
    addTarget("ms_name", 82, 548, 826, 50, "msname", 0)
    m.msRows = costRowNodes(ui, 90, 610, 42, 5)
    for i = 0 to 4
        addTarget("ms_" + i.ToStr(), 82, 604 + i * 42, 826, 40, "ms", i)
    end for

    ' ---------- Space Elevator ----------
    card(ui, 60, 850, 870, 200, "SPACE ELEVATOR")
    m.seStatus = lbl(ui, 500, 868, 400, 26, false, C.dim, "right", "")
    m.seRowsGroup = ui.createChild("Group")
    m.seRows = costRowNodes(m.seRowsGroup, 90, 905, 36, 4)
    for i = 0 to 3
        addTarget("se_" + i.ToStr(), 82, 899 + i * 36, 826, 36, "se", i)
    end for
    buildElevatorReady(ui)
    addTarget("se_ready", 82, 900, 826, 140, "seready", 0)

    ' ---------- Factory summary ----------
    card(ui, 990, 140, 870, 170, "FACTORY")
    m.effText = lbl(ui, 1430, 158, 400, 26, false, C.dim, "right", "")
    m.fs = {}
    ftiles = [["total", "MACHINES"], ["running", "RUNNING"], ["idle", "IDLE / PAUSED"], ["coupons", "COUPONS"]]
    for i = 0 to 3
        x = 1020 + i * 205
        lbl(ui, x, 205, 200, 22, false, C.dim, "", ftiles[i][1])
        m.fs[ftiles[i][0]] = lbl(ui, x, 232, 200, 50, true, C.text, "", "-")
        addTarget("fs_" + ftiles[i][0], x - 8, 198, 196, 96, "fac", i)
    end for

    ' ---------- Production ----------
    card(ui, 990, 340, 870, 710, "PRODUCTION  /min")
    m.prodCount = lbl(ui, 1430, 358, 400, 26, false, C.dim, "right", "")
    lbl(ui, 1020, 405, 300, 24, false, C.dim, "", "ITEM")
    lbl(ui, 1320, 405, 120, 24, false, C.dim, "right", "MADE")
    lbl(ui, 1450, 405, 120, 24, false, C.dim, "right", "USED")
    lbl(ui, 1580, 405, 120, 24, false, C.dim, "right", "NET")
    lbl(ui, 1710, 405, 120, 24, false, C.dim, "right", "TOTAL")
    m.prodRows = []
    for i = 0 to m.PROD_ROWS - 1
        y = 445 + i * 42
        ' Pinned-row tint + marker (created first so it sits behind the text)
        pbg = ui.createChild("Rectangle")
        pbg.translation = [1012, y - 5] : pbg.width = 836 : pbg.height = 40 : pbg.color = "0x2A2219FF"
        pbg.visible = false
        pmk = pbg.createChild("Rectangle")
        pmk.width = 5 : pmk.height = 40 : pmk.color = C.accent
        r = {
            pin: pbg,
            name: lbl(ui, 1020, y, 295, 30, false, C.text, "", ""),
            prod: lbl(ui, 1320, y, 120, 30, false, C.text, "right", ""),
            cons: lbl(ui, 1450, y, 120, 30, false, C.dim, "right", ""),
            net: lbl(ui, 1580, y, 120, 30, true, C.text, "right", ""),
            total: lbl(ui, 1710, y, 120, 30, false, C.text, "right", "")
        }
        m.prodRows.push(r)
        addTarget("pr_" + i.ToStr(), 1012, y - 5, 836, 40, "prod", i)
    end for
    m.pinSep = ui.createChild("Rectangle")
    m.pinSep.width = 836 : m.pinSep.height = 2 : m.pinSep.color = C.accent
    m.pinSep.visible = false

    m.hint = lbl(ui, 60, 1052, 1800, 22, false, "0x5A6273FF", "right", "Arrows: explore  ·  OK: pin/unpin item (or refresh)  ·  Play: preview elevator alert")

    buildFocusRing(ui)
    buildTooltip(ui)
    buildToast(ui)

    ' Chime for elevator-ready (Audio node uses the normal TV volume)
    m.audio = m.top.createChild("Audio")
    snd = CreateObject("roSGNode", "ContentNode")
    snd.url = "pkg:/sounds/elevator_ready.wav"
    m.audio.content = snd
    m.audio.observeField("state", "onAudioState")

    ' Hide focus + tooltip after 30s without key presses
    m.idleTimer = m.top.createChild("Timer")
    m.idleTimer.duration = 30
    m.idleTimer.observeField("fire", "onIdle")

    m.top.setFocus(true)
end sub

sub onConfig()
    cfg = m.top.config
    m.url = cfg.url
    m.session.text = "Connecting to " + m.url
    m.task = CreateObject("roSGNode", "FetchTask")
    m.task.baseUrl = cfg.url
    m.task.interval = cfg.interval
    m.task.observeField("result", "onResult")
    m.task.control = "RUN"
end sub

' ================= Input =================

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    m.idleTimer.control = "stop"
    m.idleTimer.control = "start"
    if key = "up" or key = "down" or key = "left" or key = "right"
        if not m.focusVisible
            m.focusVisible = true
            if m.focus = invalid or not isEnabled(m.focus) then m.focus = firstEnabled()
        else
            moveFocus(key)
        end if
        updateFocus()
        return true
    else if key = "OK"
        if m.focusVisible and m.focus <> invalid and m.focus.kind = "prod" and isEnabled(m.focus)
            togglePin()
        else if m.task <> invalid
            m.task.refreshNow = true
            showToast("Refreshing...")
        end if
        return true
    else if key = "play"
        m.demo = not m.demo
        if m.demo then playChime()
        if m.data <> invalid then renderElevator(m.data.elevator)
        updateFocus()
        return true
    else if key = "back" and m.focusVisible
        hideFocus()
        return true
    end if
    return false
end function

sub onIdle()
    hideFocus()
end sub

sub hideFocus()
    m.focusVisible = false
    m.prodOffset = 0
    if m.data <> invalid and m.data.ok = true then renderProd(m.data.prod)
    updateFocus()
end sub

sub moveFocus(dir as String)
    t = m.focus
    if t = invalid then return
    if t.kind = "prod" and m.prodView <> invalid
        avail = m.PROD_ROWS - m.prodPinned
        if dir = "down" and t.idx = m.PROD_ROWS - 1 and m.prodOffset + avail < m.prodRest
            m.prodOffset = m.prodOffset + 1
            renderProd(m.data.prod)
            return
        else if dir = "up" and t.idx = m.prodPinned and m.prodOffset > 0
            m.prodOffset = m.prodOffset - 1
            renderProd(m.data.prod)
            return
        end if
    end if
    n = findNeighbor(t, dir)
    if n <> invalid then m.focus = n
end sub

' ================= Focus targets =================

sub addTarget(id as String, x as Integer, y as Integer, w as Integer, h as Integer, kind as String, idx as Integer)
    m.targets.push({ id: id, x: x, y: y, w: w, h: h, kind: kind, idx: idx })
end sub

function isEnabled(t as Object) as Boolean
    d = m.data
    if d = invalid or d.ok <> true then return false
    k = t.kind
    if k = "power" then return d.power <> invalid
    if k = "fac"
        if t.idx = 3 then return d.sink <> invalid
        return d.factory <> invalid
    end if
    if k = "msname" then return d.hub <> invalid
    if k = "ms" then return d.hub <> invalid and d.hub.active = true and t.idx < d.hub.cost.Count()
    if k = "se" then return not m.seShowingReady and d.elevator <> invalid and t.idx < d.elevator.cost.Count()
    if k = "seready" then return m.seShowingReady
    if k = "prod" then return m.prodView <> invalid and t.idx < m.prodView.Count()
    return false
end function

function firstEnabled() as Dynamic
    for each t in m.targets
        if isEnabled(t) then return t
    end for
    return invalid
end function

' Picks the closest enabled target in the given direction.
function findNeighbor(cur as Object, dir as String) as Dynamic
    best = invalid
    bestScore = 1.0e9
    cx = cur.x + cur.w / 2
    cy = cur.y + cur.h / 2
    for each t in m.targets
        if t.id <> cur.id and isEnabled(t)
            primary = -1
            if dir = "right" and t.x >= cur.x + cur.w - 12 then primary = t.x - (cur.x + cur.w)
            if dir = "left" and t.x + t.w <= cur.x + 12 then primary = cur.x - (t.x + t.w)
            if dir = "down" and t.y >= cur.y + cur.h - 12 then primary = t.y - (cur.y + cur.h)
            if dir = "up" and t.y + t.h <= cur.y + 12 then primary = cur.y - (t.y + t.h)
            if primary >= 0
                if dir = "left" or dir = "right"
                    ortho = gap(cur.y, cur.y + cur.h, t.y, t.y + t.h)
                    tie = Abs(t.y + t.h / 2 - cy)
                else
                    ortho = gap(cur.x, cur.x + cur.w, t.x, t.x + t.w)
                    tie = Abs(t.x + t.w / 2 - cx)
                end if
                score = primary + ortho * 3 + tie * 0.05
                if score < bestScore
                    bestScore = score
                    best = t
                end if
            end if
        end if
    end for
    return best
end function

function gap(a1 as Float, a2 as Float, b1 as Float, b2 as Float) as Float
    if b2 < a1 then return a1 - b2
    if b1 > a2 then return b1 - a2
    return 0
end function

function nearestEnabled(t as Object) as Dynamic
    best = invalid
    bestD = 1.0e9
    for each c in m.targets
        if isEnabled(c)
            dx = (c.x + c.w / 2) - (t.x + t.w / 2)
            dy = (c.y + c.h / 2) - (t.y + t.h / 2)
            dd = dx * dx + dy * dy
            if dd < bestD
                bestD = dd
                best = c
            end if
        end if
    end for
    return best
end function

sub updateFocus()
    if not m.focusVisible or m.focus = invalid
        m.ring.visible = false
        m.tip.visible = false
        return
    end if
    if not isEnabled(m.focus)
        n = nearestEnabled(m.focus)
        if n = invalid
            m.ring.visible = false
            m.tip.visible = false
            return
        end if
        m.focus = n
    end if
    t = m.focus
    placeRing(t)
    showTip(t, tipFor(t))
end sub

' ================= Data / rendering =================

sub onResult()
    d = m.task.result
    C = m.C
    if not d.ok
        m.status.text = "OFFLINE"
        m.status.color = C.bad
        m.clock.text = "No response from " + m.url + "  ·  " + d.time
        if m.data <> invalid then m.data.ok = false
        updateFocus()
        return
    end if
    m.data = d

    s = d.session
    m.gamePaused = s.paused
    m.session.text = "Session: " + s.name
    if s.paused
        m.status.text = "GAME PAUSED"
        m.status.color = C.warn
    else
        m.status.text = "LIVE"
        m.status.color = C.good
    end if
    dayNight = "Night"
    if s.isDay then dayNight = "Day"
    m.clock.text = "Day " + s.day.ToStr() + " · " + s.clock + " (" + dayNight + ")  ·  Played " + s.played + "  ·  Updated " + d.time

    ' Chime when the elevator flips from "not ready" to "ready"
    if d.elevator <> invalid
        ready = elevatorReady(d.elevator)
        if m.seWasReady <> invalid and ready and not m.seWasReady then playChime()
        m.seWasReady = ready
    end if

    renderPower(d.power)
    renderProd(d.prod)
    renderFactory(d.factory, d.sink)
    renderMilestone(d.hub)
    renderElevator(d.elevator)
    updateFocus()
end sub

function elevatorReady(e as Dynamic) as Boolean
    if e = invalid or e.full = true then return false
    if e.ready = true then return true
    if e.cost.Count() = 0 then return false
    for each c in e.cost
        if c.done < c.total then return false
    end for
    return true
end function

sub renderPower(p as Dynamic)
    if p = invalid then return
    C = m.C
    m.pw.prod.text = fmt1(p.prod)
    m.pw.cons.text = fmt1(p.cons)
    m.pw.cap.text = fmt1(p.cap)
    m.pw.peak.text = fmt1(p.peak)
    m.circuits.text = plural(p.circuits, "circuit")
    frac = 0
    if p.cap > 0 then frac = p.cons / p.cap
    col = C.good
    if frac >= 0.9 then
        col = C.bad
    else if frac >= 0.7 then
        col = C.warn
    end if
    if p.peak > p.cap and col = C.good then col = C.warn
    setBar(m.loadBar, frac, col)
    txt = "Load " + Int(frac * 100 + 0.5).ToStr() + "% of capacity"
    if p.peak > p.cap then txt = txt + "  ·  Peak demand exceeds capacity!"
    if p.fuse
        txt = txt + "  ·  FUSE BLOWN"
        m.loadText.color = C.bad
    else
        txt = txt + "  ·  Fuses OK"
        m.loadText.color = C.text
    end if
    m.loadText.text = txt
    if p.batCap > 0
        pct = Int(p.batStored / p.batCap * 100 + 0.5)
        m.battery.text = "Batteries: " + pct.ToStr() + "% of " + fmt1(p.batCap) + " MWh  ·  in " + fmt1(p.batIn) + " / out " + fmt1(p.batOut) + " MW"
    else
        m.battery.text = "No power storage"
    end if
end sub

sub renderProd(rows as Dynamic)
    if rows = invalid then return
    C = m.C
    m.prodByName = {}
    for each it in rows
        m.prodByName[it.name] = it
    end for
    ' Pinned items first (in pin order), even if nothing is making them right now
    view = []
    for each name in m.pins
        it = m.prodByName[name]
        if it = invalid then it = { name: name, prod: 0.0, cons: 0.0, maxProd: 0.0, maxCons: 0.0, inactive: true }
        view.push(it)
    end for
    p = view.Count()
    rest = []
    for each it in rows
        if pinIndex(it.name) < 0 then rest.push(it)
    end for
    avail = m.PROD_ROWS - p
    maxOff = rest.Count() - avail
    if maxOff < 0 then maxOff = 0
    if m.prodOffset > maxOff then m.prodOffset = maxOff
    for j = m.prodOffset to m.prodOffset + avail - 1
        if j < rest.Count() then view.push(rest[j])
    end for
    m.prodView = view
    m.prodPinned = p
    m.prodRest = rest.Count()

    head = ""
    if p > 0 then head = p.ToStr() + " pinned  ·  "
    if rest.Count() > avail
        head = head + (m.prodOffset + 1).ToStr() + "-" + (m.prodOffset + avail).ToStr() + " of " + rest.Count().ToStr()
    else
        head = head + plural(rest.Count(), "item")
    end if
    m.prodCount.text = head

    for i = 0 to m.PROD_ROWS - 1
        r = m.prodRows[i]
        r.pin.visible = i < p
        if i < view.Count()
            it = view[i]
            r.name.text = it.name
            if it.inactive = true then r.name.color = C.dim else r.name.color = C.text
            r.prod.text = fmt1(it.prod)
            r.cons.text = fmt1(it.cons)
            net = it.prod - it.cons
            r.net.text = signed(net)
            r.net.color = netColor(net)
            r.total.text = "-"
            if m.data.inv <> invalid and m.data.inv.world <> invalid then r.total.text = compact(numOr0(m.data.inv.world[it.name]))
        else
            r.name.text = "" : r.prod.text = "" : r.cons.text = "" : r.net.text = "" : r.total.text = ""
        end if
    end for
    m.pinSep.visible = p > 0 and view.Count() > p
    m.pinSep.translation = [1012, 445 + p * 42 - 6]
end sub

' ================= Pinning =================

function pinIndex(name as String) as Integer
    for i = 0 to m.pins.Count() - 1
        if m.pins[i] = name then return i
    end for
    return -1
end function

sub togglePin()
    it = m.prodView[m.focus.idx]
    if it = invalid then return
    i = pinIndex(it.name)
    if i >= 0
        m.pins.Delete(i)
        showToast("Unpinned " + it.name)
    else
        if m.pins.Count() >= m.MAX_PINS
            showToast("Max " + m.MAX_PINS.ToStr() + " pins. Unpin one first.")
            return
        end if
        m.pins.push(it.name)
        showToast("Pinned " + it.name)
        ' Follow the item to its new spot at the top
        m.focus = targetById("pr_" + (m.pins.Count() - 1).ToStr())
    end if
    savePins()
    renderProd(m.data.prod)
    updateFocus()
end sub

function loadPins() as Object
    sec = CreateObject("roRegistrySection", "dashboard")
    if sec.Exists("pins")
        v = ParseJson(sec.Read("pins"))
        if type(v) = "roArray" then return v
    end if
    return []
end function

sub savePins()
    sec = CreateObject("roRegistrySection", "dashboard")
    sec.Write("pins", FormatJson(m.pins))
    sec.Flush()
end sub

function targetById(id as String) as Dynamic
    for each t in m.targets
        if t.id = id then return t
    end for
    return invalid
end function

sub buildToast(parent as Object)
    m.toast = parent.createChild("Group")
    m.toast.translation = [590, 26]
    m.toast.visible = false
    bg = m.toast.createChild("Rectangle")
    bg.width = 540 : bg.height = 56 : bg.color = m.C.tipBg
    st = m.toast.createChild("Rectangle")
    st.width = 6 : st.height = 56 : st.color = m.C.accent
    m.toastText = lbl(m.toast, 24, 12, 500, 28, true, m.C.text, "center", "")
    m.toastTimer = m.top.createChild("Timer")
    m.toastTimer.duration = 2.5
    m.toastTimer.observeField("fire", "onToastDone")
end sub

sub showToast(msg as String)
    m.toastText.text = msg
    m.toast.visible = true
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub onToastDone()
    m.toast.visible = false
end sub

sub renderFactory(f as Dynamic, sink as Dynamic)
    if f <> invalid
        m.fs.total.text = f.total.ToStr()
        m.fs.running.text = f.running.ToStr()
        m.fs.running.color = m.C.good
        m.fs.idle.text = f.idle.ToStr() + " / " + f.paused.ToStr()
        if f.idle > 0 then m.fs.idle.color = m.C.warn else m.fs.idle.color = m.C.text
        m.effText.text = "Avg efficiency " + Int(f.eff + 0.5).ToStr() + "%"
    end if
    if sink <> invalid then m.fs.coupons.text = commas(sink.coupons)
end sub

sub renderMilestone(h as Dynamic)
    if h = invalid then return
    if h.active = true then m.lastTier = h.tier
    if h.pod <> invalid then syncPod(h.pod)
    if not h.active
        m.msName.text = "No milestone selected"
        m.msTier.text = ""
        fillCostRows(m.msRows, [])
        return
    end if
    m.msName.text = h.name
    m.msTier.text = "·  Tier " + h.tier.ToStr()
    fillCostRows(m.msRows, h.cost)
end sub

' ---- Pod status ----
' The mod's ShipReturn countdown is used when it reports one. Some mod
' versions always report 00:00:00, so we also watch ShipDock: when the pod
' leaves we time the trip (game time, pauses excluded), and when it docks we
' remember the trip length per tier to estimate the next trip.

sub syncPod(pod as Object)
    away = not pod.docked
    if m.podAway <> invalid
        if away and not m.podAway
            m.podElapsed = 0
            m.podTier = m.lastTier
        else if not away and m.podAway
            if m.podElapsed > 0 and m.podTier >= 0 then saveTrip(m.podTier, m.podElapsed)
            m.podElapsed = -1
        end if
    end if
    m.podAway = away
    m.podSecs = pod.secs
    if away and m.podTier < 0 then m.podTier = m.lastTier
    updatePod()
end sub

sub onPodTick()
    if m.gamePaused or m.podAway <> true then return
    if m.podSecs > 0 then m.podSecs = m.podSecs - 1
    if m.podElapsed >= 0 then m.podElapsed = m.podElapsed + 1
    updatePod()
end sub

sub updatePod()
    C = m.C
    if m.podAway = invalid
        m.podLabel.text = ""
        return
    end if
    if not m.podAway
        m.podLabel.text = "Pod docked"
        m.podLabel.color = C.good
        return
    end if
    m.podLabel.color = C.accent
    if m.podSecs > 0
        m.podLabel.text = "Pod returns in " + clockText(m.podSecs)
        return
    end if
    est = loadTrip(m.podTier)
    if est > 0 and m.podElapsed >= 0
        left = est - m.podElapsed
        if left > 0
            m.podLabel.text = "Pod returns in ~" + clockText(left)
        else
            m.podLabel.text = "Pod arriving..."
        end if
    else if m.podElapsed >= 0
        m.podLabel.text = "Pod away  ·  " + clockText(m.podElapsed)
    else
        m.podLabel.text = "Pod away"
    end if
end sub

sub saveTrip(tier as Integer, secs as Integer)
    sec = CreateObject("roRegistrySection", "dashboard")
    sec.Write("podTrip_" + tier.ToStr(), secs.ToStr())
    sec.Flush()
end sub

function loadTrip(tier as Integer) as Integer
    if tier < 0 then return 0
    sec = CreateObject("roRegistrySection", "dashboard")
    key = "podTrip_" + tier.ToStr()
    if sec.Exists(key) then return Int(Val(sec.Read(key)))
    return 0
end function

function clockText(secs as Integer) as String
    h = secs \ 3600
    mm = (secs MOD 3600) \ 60
    ss = secs MOD 60
    t = ""
    if h > 0 then t = h.ToStr() + ":" + pad2(mm) else t = mm.ToStr()
    return t + ":" + pad2(ss)
end function

function pad2(n as Integer) as String
    if n < 10 then return "0" + n.ToStr()
    return n.ToStr()
end function

sub renderElevator(e as Dynamic)
    showReady = m.demo or elevatorReady(e)
    m.seShowingReady = showReady
    m.seRowsGroup.visible = not showReady
    m.seReady.visible = showReady
    if showReady
        if m.seAnim.state <> "running" then m.seAnim.control = "start"
        if m.demo
            m.seStatus.text = "Preview (press Play to exit)"
        else
            m.seStatus.text = "All parts delivered"
        end if
        m.seStatus.color = m.C.good
        return
    end if
    m.seAnim.control = "stop"
    if e = invalid then return
    if e.full = true
        m.seStatus.text = "Fully upgraded"
    else
        m.seStatus.text = "Current phase"
    end if
    m.seStatus.color = m.C.dim
    fillCostRows(m.seRows, e.cost)
end sub

sub fillCostRows(nodes as Object, cost as Object)
    for i = 0 to nodes.Count() - 1
        n = nodes[i]
        if i < cost.Count()
            c = cost[i]
            n.name.text = c.name
            n.count.text = commas(c.done) + " / " + commas(c.total)
            frac = 0
            if c.total > 0 then frac = c.done / c.total
            col = m.C.accent
            if frac >= 1 then col = m.C.good
            setBar(n.bar, frac, col)
            n.bar.bg.visible = true
        else
            n.name.text = "" : n.count.text = ""
            n.bar.bg.visible = false
            n.bar.fill.width = 0
        end if
    end for
end sub

' ================= Tooltip content =================
' Rows are [key, value]. A key starting with "#" is a section header;
' an empty value lets the key span the full width.

function tipFor(t as Object) as Object
    d = m.data
    k = t.kind
    if k = "power" then return powerTip(t.idx, d.power, d.generators, d.factory)
    if k = "fac" then return factoryTip(t.idx, d.factory, d.sink)
    if k = "msname"
        rows = [["#UNLOCKS", ""]]
        if d.hub.active = true and d.hub.unlocks <> invalid
            for each u in d.hub.unlocks
                rows.push([u, ""])
            end for
        else
            rows.push(["Pick a milestone at the HUB", ""])
        end if
        return { title: m.msName.text, rows: rows }
    end if
    if k = "ms" then return costTip(d.hub.cost[t.idx], "Milestone")
    if k = "se" then return costTip(d.elevator.cost[t.idx], "Space Elevator")
    if k = "seready"
        rows = [["Head to the Space Elevator and send it up!", ""], ["#PARTS", ""]]
        if d.elevator <> invalid
            for each c in d.elevator.cost
                rows.push([c.name, commas(c.done) + " / " + commas(c.total)])
            end for
        end if
        return { title: "Ready to submit", rows: rows }
    end if
    if k = "prod"
        it = m.prodView[t.idx]
        rows = itemRows(it.name)
        if pinIndex(it.name) >= 0
            rows.push(["#PINNED  ·  OK TO UNPIN", ""])
        else if m.pins.Count() < m.MAX_PINS
            rows.push(["#OK TO PIN TO TOP", ""])
        else
            rows.push(["#PIN LIMIT REACHED (" + m.MAX_PINS.ToStr() + ")", ""])
        end if
        return { title: it.name, rows: rows }
    end if
    return { title: "", rows: [] }
end function

function itemRows(name as String) as Object
    rows = [["#PRODUCTION", ""]]
    p = m.prodByName[name]
    if p <> invalid
        rows.push(["Made /min", fmt1(p.prod) + " of " + fmt1(p.maxProd) + " max"])
        rows.push(["Used /min", fmt1(p.cons) + " of " + fmt1(p.maxCons) + " max"])
        rows.push(["Net /min", signed(p.prod - p.cons)])
    else
        rows.push(["Made /min", "Not produced"])
    end if
    inv = m.data.inv
    if inv <> invalid
        rows.push(["#ON HAND", ""])
        nc = inv.storage["__containers"]
        lab = "In storage containers"
        if nc <> invalid then lab = "In storage (" + commas(nc) + " containers)"
        rows.push([lab, commas(numOr0(inv.storage[name]))])
        rows.push(["Total in world", commas(numOr0(inv.world[name]))])
        cl = numOr0(inv.cloud[name])
        if cl > 0 then rows.push(["Dimensional Depot", commas(cl)])
    end if
    f = m.data.factory
    if f <> invalid and f.producers <> invalid
        pr = f.producers[name]
        if pr <> invalid and pr.Count() > 0
            rows.push(["#MADE BY", ""])
            for each e in pr
                rows.push([e.name, plural(e.count, "machine")])
            end for
        end if
    end if
    return rows
end function

function costTip(c as Object, where as String) as Object
    remaining = c.total - c.done
    rows = [["#" + UCase(where), ""], ["Delivered", commas(c.done) + " / " + commas(c.total)]]
    if remaining <= 0
        rows.push(["Status", "Complete"])
    else
        rows.push(["Still needed", commas(remaining)])
        p = m.prodByName[c.name]
        eta = "Not produced"
        if p <> invalid
            net = p.prod - p.cons
            if net > 0.01
                eta = "~" + duration(remaining / net)
            else
                eta = "No surplus"
            end if
        end if
        rows.push(["Time to make (net rate)", eta])
    end if
    rows.append(recipeRows(c.name, remaining))
    rows.append(itemRows(c.name))
    return { title: c.name, rows: rows }
end function

function recipeRows(item as String, remaining as Float) as Object
    rows = []
    if m.data.recipes = invalid then return rows
    list = m.data.recipes[item]
    if list = invalid then return rows
    for each rc in list
        head = "COMPONENTS · " + rc.building
        if rc.alt then head = "ALT: " + rc.name + " · " + rc.building
        if rc.inUse = true then head = head + " · IN USE"
        valHead = "per craft"
        if remaining > 0 then valHead = "each · for rest"
        rows.push(["#" + UCase(head), valHead])
        outAmt = rc.out
        if outAmt <= 0 then outAmt = 1
        for each ing in rc.ing
            v = fmt1(ing.amount)
            if outAmt <> 1 then v = v + " per " + fmt1(outAmt)
            if remaining > 0
                need = -Int(-(remaining * ing.amount / outAmt))
                v = v + "  ·  " + commas(need)
            end if
            rows.push([ing.name, v])
        end for
    end for
    return rows
end function

function powerTip(idx as Integer, p as Dynamic, gens as Dynamic, f as Dynamic) as Object
    rows = []
    if idx = 0 or idx = 2
        title = "Power production"
        if idx = 2 then title = "Power capacity"
        if gens = invalid or gens.Count() = 0
            rows.push(["No generators found", ""])
        else
            rows.push(["#GENERATORS", "now / max MW"])
            for each g in gens
                rows.push([g.name + "  x" + g.count.ToStr(), fmt1(g.out) + " / " + fmt1(g.cap)])
            end for
        end if
        if idx = 2 then rows.push(["Headroom", fmt1(p.cap - p.cons) + " MW"])
        return { title: title, rows: rows }
    end if
    if idx = 1 or idx = 3
        title = "Power consumption"
        head = "now MW"
        if idx = 3
            title = "Peak demand"
            head = "max MW"
        end if
        if f <> invalid and f.consumers <> invalid
            list = f.consumers
            if idx = 3
                list = []
                for each c in f.consumers
                    list.push(c)
                end for
                list.SortBy("max", "r")
            end if
            rows.push(["#BY MACHINE TYPE", head])
            for each c in list
                v = c.cur
                if idx = 3 then v = c.max
                rows.push([c.name + "  x" + c.count.ToStr(), fmt1(v)])
            end for
        end if
        if idx = 3 then rows.push(["Margin vs capacity", signed(p.cap - p.peak) + " MW"])
        return { title: title, rows: rows }
    end if
    ' Load bar: circuits + storage
    rows.push(["#CIRCUITS", "use / cap MW"])
    for each c in p.list
        v = fmt1(c.cons) + " / " + fmt1(c.cap)
        if c.fuse then v = "FUSE BLOWN"
        rows.push(["Circuit " + c.id.ToStr() + "  (makes " + fmt1(c.prod) + ")", v])
    end for
    rows.push(["#STORAGE", ""])
    if p.batCap > 0
        rows.push(["Stored", fmt1(p.batStored) + " / " + fmt1(p.batCap) + " MWh"])
        rows.push(["Charging / draining", fmt1(p.batIn) + " / " + fmt1(p.batOut) + " MW"])
    else
        rows.push(["No batteries built", ""])
    end if
    return { title: "Power grid", rows: rows }
end function

function factoryTip(idx as Integer, f as Dynamic, sink as Dynamic) as Object
    rows = []
    if idx = 3
        if sink = invalid then return { title: "Coupons", rows: [] }
        rows.push(["Coupons available", commas(sink.coupons)])
        rows.push(["Total sink points", commas(sink.points)])
        rows.push(["Points to next coupon", commas(sink.toNext)])
        rows.push(["Progress to next", Int(sink.percent * 100 + 0.5).ToStr() + "%"])
        return { title: "Resource sink", rows: rows }
    end if
    if idx = 0
        rows.push(["#PRODUCTION BUILDINGS", "running / total"])
        for each t in f.types
            if not t.ext then rows.push([t.name, t.running.ToStr() + " / " + t.count.ToStr()])
        end for
        if f.extractors > 0
            rows.push(["#EXTRACTORS", ""])
            for each t in f.types
                if t.ext then rows.push([t.name, t.running.ToStr() + " / " + t.count.ToStr()])
            end for
        end if
        return { title: "Machines", rows: rows }
    end if
    if idx = 1
        rows.push(["#RUNNING NOW", "count · eff"])
        for each e in f.running_list
            rows.push([e.name, e.count.ToStr() + "  ·  " + Int(e.eff + 0.5).ToStr() + "%"])
        end for
        return { title: "Running machines", rows: rows }
    end if
    if f.idle_list.Count() = 0
        rows.push(["Everything is running", ""])
    else
        for each e in f.idle_list
            rows.push([e.name, e.reason])
        end for
    end if
    return { title: "Idle / paused machines", rows: rows }
end function

' ================= Elevator ready / sound =================

sub buildElevatorReady(parent as Object)
    g = parent.createChild("Group")
    g.visible = false
    m.seReady = g
    badge = g.createChild("Poster")
    badge.id = "seBadge"
    badge.uri = "pkg:/images/elevator_ready.png"
    badge.width = 130 : badge.height = 130
    badge.translation = [96, 906]
    badge.scaleRotateCenter = [65, 65]
    lbl(g, 260, 920, 640, 48, true, m.C.good, "", "READY TO SUBMIT")
    lbl(g, 262, 980, 640, 26, false, m.C.text, "", "All parts delivered. Send the next phase up!")

    anim = g.createChild("Animation")
    anim.duration = 1.6
    anim.repeat = true
    anim.easeFunction = "inOutQuad"
    interp = anim.createChild("Vector2DFieldInterpolator")
    interp.key = [0.0, 0.5, 1.0]
    interp.keyValue = [[1.0, 1.0], [1.08, 1.08], [1.0, 1.0]]
    interp.fieldToInterp = "seBadge.scale"
    m.seAnim = anim
end sub

sub playChime()
    m.audio.control = "stop"
    m.audio.control = "play"
end sub

sub onAudioState()
    print "[chime] audio state: "; m.audio.state
end sub

' ================= Focus ring & tooltip =================

sub buildFocusRing(parent as Object)
    m.ring = parent.createChild("Group")
    m.ring.visible = false
    m.ringSides = []
    for i = 0 to 3
        r = m.ring.createChild("Rectangle")
        r.color = m.C.accent
        m.ringSides.push(r)
    end for
end sub

sub placeRing(t as Object)
    th = 3
    s = m.ringSides
    s[0].translation = [t.x, t.y] : s[0].width = t.w : s[0].height = th
    s[1].translation = [t.x, t.y + t.h - th] : s[1].width = t.w : s[1].height = th
    s[2].translation = [t.x, t.y] : s[2].width = th : s[2].height = t.h
    s[3].translation = [t.x + t.w - th, t.y] : s[3].width = th : s[3].height = t.h
    m.ring.visible = true
end sub

sub buildTooltip(parent as Object)
    m.TIP_W = 640
    m.TIP_ROWS = 18
    m.tip = parent.createChild("Group")
    m.tip.visible = false
    m.tipShadow = m.tip.createChild("Rectangle")
    m.tipShadow.color = "0x00000088"
    m.tipShadow.translation = [8, 8]
    m.tipBg = m.tip.createChild("Rectangle")
    m.tipBg.color = m.C.tipBg
    m.tipStripe = m.tip.createChild("Rectangle")
    m.tipStripe.color = m.C.accent
    m.tipStripe.width = 6
    m.tipTitle = lbl(m.tip, 26, 18, m.TIP_W - 48, 32, true, m.C.accent, "", "")
    m.tipRows = []
    for i = 0 to m.TIP_ROWS - 1
        m.tipRows.push({
            k: lbl(m.tip, 26, 0, 400, 25, false, m.C.text, "", ""),
            v: lbl(m.tip, 430, 0, m.TIP_W - 456, 25, false, m.C.text, "right", "")
        })
    end for
end sub

sub showTip(t as Object, tip as Object)
    rows = tip.rows
    n = rows.Count()
    if n > m.TIP_ROWS
        extra = n - m.TIP_ROWS + 1
        trimmed = []
        for i = 0 to m.TIP_ROWS - 2
            trimmed.push(rows[i])
        end for
        trimmed.push(["+ " + extra.ToStr() + " more", ""])
        rows = trimmed
        n = rows.Count()
    end if
    m.tipTitle.text = tip.title
    y = 66
    for i = 0 to m.TIP_ROWS - 1
        r = m.tipRows[i]
        if i < n
            key = rows[i][0]
            val = rows[i][1]
            r.k.visible = true : r.v.visible = true
            if Left(key, 1) = "#"
                if i > 0 then y = y + 8
                r.k.text = Mid(key, 2)
                r.k.font.size = 21
                r.k.color = m.C.dim
                r.v.font.size = 21
                r.v.color = m.C.dim
            else
                r.k.text = key
                r.k.font.size = 25
                r.k.color = m.C.text
                r.v.font.size = 25
                r.v.color = m.C.text
            end if
            if val = ""
                r.k.width = m.TIP_W - 52
            else
                r.k.width = 400
            end if
            r.v.text = val
            r.k.translation = [26, y]
            r.v.translation = [430, y]
            y = y + 36
        else
            r.k.visible = false : r.v.visible = false
        end if
    end for
    h = y + 14
    m.tipBg.width = m.TIP_W : m.tipBg.height = h
    m.tipShadow.width = m.TIP_W : m.tipShadow.height = h
    m.tipStripe.height = h

    ' Place to the right of the target if it fits, else to the left; keep on screen
    x = t.x + t.w + 16
    if x + m.TIP_W > 1900 then x = t.x - 16 - m.TIP_W
    if x < 20 then x = 20
    ty = t.y
    if ty + h > 1060 then ty = 1060 - h
    if ty < 20 then ty = 20
    m.tip.translation = [x, ty]
    m.tip.visible = true
end sub

' ================= Builders / helpers =================

function lbl(parent as Object, x as Integer, y as Integer, w as Integer, size as Integer, bold as Boolean, color as String, align as String, text as String) as Object
    l = parent.createChild("Label")
    l.translation = [x, y]
    if w > 0 then l.width = w
    if bold then l.font = "font:MediumBoldSystemFont" else l.font = "font:MediumSystemFont"
    l.font.size = size
    l.color = color
    if align <> "" then l.horizAlign = align
    l.text = text
    return l
end function

sub card(parent as Object, x as Integer, y as Integer, w as Integer, h as Integer, title as String)
    r = parent.createChild("Rectangle")
    r.translation = [x, y] : r.width = w : r.height = h : r.color = m.C.card
    s = parent.createChild("Rectangle")
    s.translation = [x, y] : s.width = 6 : s.height = h : s.color = m.C.accent
    lbl(parent, x + 30, y + 16, 0, 28, true, m.C.accent, "", title)
end sub

function bar(parent as Object, x as Integer, y as Integer, w as Integer, h as Integer) as Object
    bg = parent.createChild("Rectangle")
    bg.translation = [x, y] : bg.width = w : bg.height = h : bg.color = m.C.track
    fill = bg.createChild("Rectangle")
    fill.width = 0 : fill.height = h : fill.color = m.C.accent
    return { bg: bg, fill: fill, w: w }
end function

sub setBar(b as Object, frac as Float, color as String)
    if frac < 0 then frac = 0
    if frac > 1 then frac = 1
    b.fill.width = Int(b.w * frac)
    b.fill.color = color
end sub

function costRowNodes(parent as Object, x as Integer, y as Integer, stepY as Integer, n as Integer) as Object
    rows = []
    for i = 0 to n - 1
        yy = y + i * stepY
        rows.push({
            name: lbl(parent, x, yy, 290, 28, false, m.C.text, "", ""),
            bar: bar(parent, x + 300, yy + 8, 330, 16),
            count: lbl(parent, x + 640, yy, 170, 28, false, m.C.dim, "right", "")
        })
        rows[i].bar.bg.visible = false
    end for
    return rows
end function

function plural(n as Integer, word as String) as String
    if n = 1 then return "1 " + word
    return n.ToStr() + " " + word + "s"
end function

function numOr0(v as Dynamic) as Float
    if v = invalid then return 0
    return v
end function

function signed(v as Dynamic) as String
    if v >= 0.05 then return "+" + fmt1(v)
    if v <= -0.05 then return fmt1(v)
    return "0"
end function

function netColor(v as Dynamic) as String
    if v >= 0.05 then return m.C.good
    if v <= -0.05 then return m.C.bad
    return m.C.dim
end function

function duration(mins as Float) as String
    if mins < 1 then return "under 1 min"
    if mins < 60 then return Int(mins + 0.5).ToStr() + " min"
    h = Int(mins / 60)
    mm = Int(mins - h * 60 + 0.5)
    if h >= 48 then return Int(h / 24 + 0.5).ToStr() + " days"
    return h.ToStr() + "h " + mm.ToStr() + "m"
end function

' Commas below 100k, then 123k / 1.2M so it fits the column
function compact(v as Dynamic) as String
    if v < 100000 then return commas(v)
    if v < 1000000 then return Int(v / 1000 + 0.5).ToStr() + "k"
    return fmt1(v / 1000000) + "M"
end function

function commas(v as Dynamic) as String
    neg = v < 0
    s = Int(Abs(v) + 0.5).ToStr()
    out = ""
    while Len(s) > 3
        out = "," + Right(s, 3) + out
        s = Left(s, Len(s) - 3)
    end while
    out = s + out
    if neg then out = "-" + out
    return out
end function

function fmt1(v as Dynamic) as String
    neg = v < 0
    i = Int(Abs(v) * 10 + 0.5)
    whole = i \ 10
    dec = i MOD 10
    s = commas(whole)
    if dec <> 0 then s = s + "." + dec.ToStr()
    if neg and i > 0 then s = "-" + s
    return s
end function
