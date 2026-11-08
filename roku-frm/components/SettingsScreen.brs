' Settings: server address and on/off display options.

sub init()
    m.C = {
        text: "0xE6E8ECFF", dim: "0x8A93A3FF", accent: "0xFA9549FF", card: "0x181B22FF",
        good: "0x4CC38AFF", bg: "0x0F1115FF"
    }
    C = m.C
    ' Each toggle: registry key, menu label, help text
    m.toggles = [
        { key: "autoPinMilestone", label: "Auto-pin milestone parts", help: "Pins the parts of the current milestone to the top of the production list, so you can see how fast you're making them. They change automatically when you pick a new milestone." },
        { key: "autoPinElevator", label: "Auto-pin Space Elevator parts", help: "Pins the parts of the current Space Elevator phase to the top of the production list. They change automatically when the next phase starts." }
    ]

    bg = m.top.createChild("Rectangle")
    bg.width = 1920 : bg.height = 1080 : bg.color = C.bg
    hdr = m.top.createChild("Rectangle")
    hdr.width = 1920 : hdr.height = 110 : hdr.color = "0x14171DFF"
    acc = m.top.createChild("Rectangle")
    acc.translation = [0, 106] : acc.width = 1920 : acc.height = 4 : acc.color = C.accent
    lbl(60, 18, 0, 46, true, C.accent, "FACTORY DASHBOARD")
    lbl(62, 68, 900, 28, false, C.dim, "Settings")
    lbl(160, 170, 1600, 56, true, C.text, "Settings")

    m.menu = m.top.createChild("LabelList")
    m.menu.id = "menu"
    m.menu.translation = [160, 270]
    m.menu.itemSize = [760, 64]
    m.menu.numRows = 6
    m.menu.vertFocusAnimationStyle = "floatingFocus"
    m.menu.color = C.text
    m.menu.focusedColor = C.bg
    m.menu.focusBitmapBlendColor = C.accent
    m.menu.font = "font:MediumSystemFont"
    m.menu.font.size = 32
    m.menu.focusedFont = "font:MediumBoldSystemFont"
    m.menu.focusedFont.size = 32
    m.menu.observeField("itemSelected", "onSelect")
    m.menu.observeField("itemFocused", "onFocus")

    panel = m.top.createChild("Rectangle")
    panel.translation = [1000, 270] : panel.width = 760 : panel.height = 300 : panel.color = C.card
    stripe = m.top.createChild("Rectangle")
    stripe.translation = [1000, 270] : stripe.width = 6 : stripe.height = 300 : stripe.color = C.accent
    m.help = lbl(1036, 298, 690, 30, false, C.text, "")
    m.help.wrap = true

    lbl(60, 1040, 1800, 24, false, "0x5A6273FF", "OK: change  ·  Back: return to dashboard")
    buildMenu()
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

' Menu rows: 0 = server, 1.. = toggles, last = back
sub buildMenu()
    focused = m.menu.itemFocused
    content = CreateObject("roSGNode", "ContentNode")
    srv = "Not set"
    if m.top.server <> "" then srv = hostOf(m.top.server)
    add(content, "Server: " + srv)
    for each t in m.toggles
        state = "Off"
        if loadFlag(t.key) then state = "On"
        add(content, t.label + ": " + state)
    end for
    add(content, "Back to dashboard")
    m.menu.content = content
    if focused > 0 then m.menu.jumpToItem = focused
    onFocus()
end sub

sub add(content as Object, title as String)
    c = content.createChild("ContentNode")
    c.title = title
end sub

sub onFocus()
    i = m.menu.itemFocused
    if i < 0 then i = 0
    if i = 0
        m.help.text = "Change the address of the PC or server running Satisfactory with the Ficsit Remote Monitoring web server, or search your network for it."
    else if i <= m.toggles.Count()
        t = m.toggles[i - 1]
        state = "off"
        if loadFlag(t.key) then state = "on"
        m.help.text = t.help + Chr(10) + Chr(10) + "Currently " + state + ". Press OK to turn it " + flip(state) + "."
    else
        m.help.text = "Return to the dashboard."
    end if
end sub

function flip(state as String) as String
    if state = "on" then return "off"
    return "on"
end function

sub onSelect()
    i = m.menu.itemSelected
    if i = 0
        m.top.finished = "server"
    else if i <= m.toggles.Count()
        t = m.toggles[i - 1]
        saveFlag(t.key, not loadFlag(t.key))
        buildMenu()
    else
        m.top.finished = "done"
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press and key = "back"
        m.top.finished = "done"
        return true
    end if
    return false
end function
