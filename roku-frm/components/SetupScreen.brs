' Server address setup: type it in, search the network, or test & connect.

sub init()
    m.C = {
        text: "0xE6E8ECFF", dim: "0x8A93A3FF", accent: "0xFA9549FF", card: "0x181B22FF",
        good: "0x4CC38AFF", bad: "0xEB5757FF", bg: "0x0F1115FF"
    }
    C = m.C
    m.addrUrl = ""
    m.found = []
    m.busy = false

    bg = m.top.createChild("Rectangle")
    bg.width = 1920 : bg.height = 1080 : bg.color = C.bg
    hdr = m.top.createChild("Rectangle")
    hdr.width = 1920 : hdr.height = 110 : hdr.color = "0x14171DFF"
    acc = m.top.createChild("Rectangle")
    acc.translation = [0, 106] : acc.width = 1920 : acc.height = 4 : acc.color = C.accent
    lbl(60, 18, 0, 46, true, C.accent, "FACTORY DASHBOARD")
    lbl(62, 68, 900, 28, false, C.dim, "Server settings")

    lbl(160, 170, 1600, 56, true, C.text, "Connect to your factory")
    intro = lbl(160, 250, 1600, 30, false, C.dim, "This dashboard reads live data from the Ficsit Remote Monitoring mod. Enter the IP address of the PC running Satisfactory (or your dedicated server) with the mod's web server enabled. The default port is 8080.")
    intro.wrap = true

    lbl(160, 390, 800, 24, false, C.dim, "SERVER ADDRESS")
    m.addr = lbl(160, 420, 1600, 44, true, C.text, "Not set")

    m.menu = m.top.createChild("LabelList")
    m.menu.id = "menu"
    m.menu.translation = [160, 520]
    m.menu.itemSize = [760, 64]
    m.menu.numRows = 7
    m.menu.vertFocusAnimationStyle = "floatingFocus"
    m.menu.color = C.text
    m.menu.focusedColor = C.bg
    m.menu.focusBitmapBlendColor = C.accent
    m.menu.font = "font:MediumSystemFont"
    m.menu.font.size = 32
    m.menu.focusedFont = "font:MediumBoldSystemFont"
    m.menu.focusedFont.size = 32
    m.menu.observeField("itemSelected", "onSelect")
    buildMenu()

    panel = m.top.createChild("Rectangle")
    panel.translation = [1000, 520] : panel.width = 760 : panel.height = 340 : panel.color = C.card
    stripe = m.top.createChild("Rectangle")
    stripe.translation = [1000, 520] : stripe.width = 6 : stripe.height = 340 : stripe.color = C.accent
    m.status = lbl(1036, 548, 690, 30, false, C.dim, "Choose an option on the left.")
    m.status.wrap = true

    m.footer = lbl(60, 1040, 1800, 24, false, "0x5A6273FF", "")
    m.top.observeField("canCancel", "onCanCancel")
    onCanCancel()
end sub

function lbl(x as Integer, y as Integer, w as Integer, size as Integer, bold as Boolean, color as String, text as String) as Object
    l = m.top.createChild("Label")
    l.translation = [x, y]
    if w > 0 then l.width = w
    if bold then l.font = "font:MediumBoldSystemFont" else l.font = "font:MediumSystemFont"
    l.font.size = size
    l.color = color
    l.text = text
    return l
end function

sub onCanCancel()
    if m.top.canCancel
        m.footer.text = "Back: return to dashboard"
    else
        m.footer.text = "Back: exit"
    end if
end sub

sub buildMenu()
    content = CreateObject("roSGNode", "ContentNode")
    items = ["Enter server address", "Search my network", "Connect"]
    for each f in m.found
        items.push("Use " + hostOf(f.url) + "  (" + f.session + ")")
    end for
    for each t in items
        c = content.createChild("ContentNode")
        c.title = t
    end for
    m.menu.content = content
end sub

sub onServer()
    setAddr(m.top.server)
end sub

sub onMessage()
    status(m.top.message, m.top.messageKind)
end sub

sub setAddr(url as String)
    m.addrUrl = url
    if url = "" then m.addr.text = "Not set" else m.addr.text = hostOf(url)
end sub

sub status(text as String, kind as String)
    m.status.text = text
    if kind = "good"
        m.status.color = m.C.good
    else if kind = "bad"
        m.status.color = m.C.bad
    else
        m.status.color = m.C.text
    end if
end sub

sub onSelect()
    if m.busy then return
    i = m.menu.itemSelected
    if i = 0
        openKeyboard()
    else if i = 1
        startScan()
    else if i = 2
        testAndConnect(m.addrUrl)
    else if i - 3 < m.found.Count()
        f = m.found[i - 3]
        setAddr(f.url)
        testAndConnect(f.url)
    end if
end sub

' ---- Keyboard ----

sub openKeyboard()
    kb = CreateObject("roSGNode", "StandardKeyboardDialog")
    kb.title = "Server address"
    kb.message = ["IP address of the PC running the mod, with the port if it isn't 8080. Example: 192.168.1.20:8080"]
    kb.buttons = ["OK", "Cancel"]
    if m.addrUrl <> "" then kb.text = hostOf(m.addrUrl)
    kb.observeField("buttonSelected", "onKbButton")
    kb.observeField("wasClosed", "onKbClosed")
    m.kb = kb
    m.top.getScene().dialog = kb
end sub

sub onKbButton()
    if m.kb.buttonSelected = 0
        url = normalizeServer(m.kb.text)
        if url = ""
            status("That doesn't look like an address. Use an IP like 192.168.1.20, or 192.168.1.20:8080 for a specific port.", "bad")
        else
            setAddr(url)
            status("Press Connect to test " + hostOf(url) + ".", "dim")
            m.menu.jumpToItem = 2
        end if
    end if
    m.kb.close = true
end sub

sub onKbClosed()
    m.menu.setFocus(true)
end sub

' ---- Test & connect ----

sub testAndConnect(url as String)
    if url = ""
        status("Enter a server address or search your network first.", "bad")
        return
    end if
    m.busy = true
    status("Connecting to " + hostOf(url) + "...", "dim")
    m.probe = CreateObject("roSGNode", "ProbeTask")
    m.probe.mode = "test"
    m.probe.url = url
    m.probe.observeField("result", "onProbe")
    m.probe.control = "RUN"
end sub

sub onProbe()
    r = m.probe.result
    m.busy = false
    if r.ok
        status("Connected to " + r.session + ". Opening the dashboard...", "good")
        m.top.finished = r.url
    else
        status(errorText(r.kind, r.code, r.url), "bad")
    end if
end sub

' ---- Network search ----

sub startScan()
    m.busy = true
    port = 8080
    if m.addrUrl <> "" then port = portOf(m.addrUrl)
    m.scanPort = port
    status("Searching your network for the mod on port " + port.ToStr() + "...", "dim")
    m.scan = CreateObject("roSGNode", "ProbeTask")
    m.scan.mode = "scan"
    m.scan.port = port
    m.scan.observeField("progress", "onScanProgress")
    m.scan.observeField("result", "onScanDone")
    m.scan.control = "RUN"
end sub

sub onScanProgress()
    status("Searching your network for the mod on port " + m.scanPort.ToStr() + "...  " + m.scan.progress.ToStr() + "%", "dim")
end sub

sub onScanDone()
    r = m.scan.result
    m.busy = false
    m.found = r.found
    buildMenu()
    if m.found.Count() = 0
        where = "your network"
        if r.prefix <> "" then where = r.prefix + "x"
        status("Didn't find the mod on " + where + " (port " + r.port.ToStr() + "). Make sure the game is running with the mod's web server started, or enter the address yourself.", "bad")
    else if m.found.Count() = 1
        f = m.found[0]
        setAddr(f.url)
        status("Found " + f.session + " at " + hostOf(f.url) + ". Press Connect.", "good")
        m.menu.jumpToItem = 2
    else
        status("Found " + m.found.Count().ToStr() + " servers. Pick one from the list.", "good")
        m.menu.jumpToItem = 3
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press and key = "back" and m.top.canCancel
        m.top.finished = "cancel"
        return true
    end if
    return false
end function
