' Helpers shared by the scene, setup screen and background tasks.

' GET a URL with a hard timeout. code: HTTP status, negative curl error,
' or 0 if we gave up waiting.
function httpGet(url as String, timeoutMs as Integer) as Object
    xfer = CreateObject("roUrlTransfer")
    p = CreateObject("roMessagePort")
    xfer.SetMessagePort(p)
    xfer.SetUrl(url)
    xfer.EnableEncodings(true)
    if not xfer.AsyncGetToString() then return { code: -1, body: "" }
    msg = wait(timeoutMs, p)
    if type(msg) = "roUrlEvent" then return { code: msg.GetResponseCode(), body: msg.GetString() }
    xfer.AsyncCancel()
    return { code: 0, body: "" }
end function

function classifyFailure(code as Integer) as String
    if code = 0 or code = -28 then return "timeout"
    if code = -7 then return "refused"
    if code = -6 then return "resolve"
    if code = 200 or code = 404 then return "notfrm"
    if code > 0 then return "http"
    return "network"
end function

function errorText(kind as String, code as Integer, url as String) as String
    host = hostOf(url)
    if kind = "timeout" then return "No response from " + host + ". Check the IP address, that the PC or server is on, and that a firewall isn't blocking the port."
    if kind = "refused" then return "Reached the computer at " + host + ", but nothing is listening on that port. Make sure Satisfactory is running and the Ficsit Remote Monitoring web server is started."
    if kind = "resolve" then return "Couldn't find " + host + ". Check the address."
    if kind = "notfrm" then return "Something answered at " + host + ", but it isn't Ficsit Remote Monitoring. Check the port number."
    if kind = "http" then return "The server at " + host + " returned an error (HTTP " + code.ToStr() + ")."
    return "Couldn't connect to " + host + " (error " + code.ToStr() + ")."
end function

' "192.168.1.20", "192.168.1.20:8080" or "http://..." -> "http://host:port"; "" if invalid
function normalizeServer(input as Dynamic) as String
    if input = invalid then return ""
    s = input.Trim()
    if LCase(Left(s, 7)) = "http://" then s = Mid(s, 8)
    while Len(s) > 0 and Right(s, 1) = "/"
        s = Left(s, Len(s) - 1)
    end while
    if s = "" then return ""
    re = CreateObject("roRegex", "^[A-Za-z0-9.\-]+(:[0-9]{1,5})?$", "")
    if not re.IsMatch(s) then return ""
    if Instr(1, s, ":") = 0 then s = s + ":8080"
    return "http://" + s
end function

function hostOf(url as String) as String
    if LCase(Left(url, 7)) = "http://" then return Mid(url, 8)
    return url
end function

function portOf(url as String) as Integer
    h = hostOf(url)
    i = Instr(1, h, ":")
    if i = 0 then return 8080
    return Int(Val(Mid(h, i + 1)))
end function

function loadServer() as String
    sec = CreateObject("roRegistrySection", "dashboard")
    if sec.Exists("server") then return sec.Read("server")
    return ""
end function

sub saveServer(url as String)
    sec = CreateObject("roRegistrySection", "dashboard")
    sec.Write("server", url)
    sec.Flush()
end sub

' On/off settings, stored as "1" / "0". Missing means off.
function loadFlag(key as String) as Boolean
    sec = CreateObject("roRegistrySection", "dashboard")
    return sec.Exists(key) and sec.Read(key) = "1"
end function

sub saveFlag(key as String, value as Boolean)
    sec = CreateObject("roRegistrySection", "dashboard")
    if value then sec.Write(key, "1") else sec.Write(key, "0")
    sec.Flush()
end sub
