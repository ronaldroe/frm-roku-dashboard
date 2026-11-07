' Tests one server address, or scans the local /24 for the mod.

sub init()
    m.top.functionName = "run"
end sub

sub run()
    if m.top.mode = "scan"
        r = scan(m.top.port)
        ' Fall back to the mod's default port if the entered one finds nothing
        if not r.ok and m.top.port <> 8080 and r.prefix <> ""
            r2 = scan(8080)
            if r2.ok then r = r2
        end if
        m.top.result = r
    else
        m.top.result = probe(m.top.url)
    end if
end sub

function probe(url as String) as Object
    r = httpGet(url + "/getSessionInfo", 6000)
    print "[probe] "; url; " -> "; r.code
    if r.code = 200
        j = ParseJson(r.body)
        if j <> invalid and j.SessionName <> invalid then return { ok: true, session: j.SessionName, url: url }
    end if
    return { ok: false, kind: classifyFailure(r.code), code: r.code, url: url }
end function

function scan(port as Integer) as Object
    prefix = ""
    ips = CreateObject("roDeviceInfo").GetIPAddrs()
    for each k in ips
        parts = ips[k].Split(".")
        if prefix = "" and parts.Count() = 4 then prefix = parts[0] + "." + parts[1] + "." + parts[2] + "."
    end for
    if prefix = "" then return { ok: false, found: [], prefix: "", port: port }

    found = []
    p = CreateObject("roMessagePort")
    host = 1
    while host <= 254
        ' Probe 32 hosts at a time; anything silent after 1.5 s is skipped
        batch = {}
        while host <= 254 and batch.Count() < 32
            base = "http://" + prefix + host.ToStr() + ":" + port.ToStr()
            x = CreateObject("roUrlTransfer")
            x.SetMessagePort(p)
            x.SetUrl(base + "/getSessionInfo")
            if x.AsyncGetToString() then batch[x.GetIdentity().ToStr()] = { x: x, url: base }
            host = host + 1
        end while
        clock = CreateObject("roTimespan")
        while batch.Count() > 0 and clock.TotalMilliseconds() < 1500
            msg = wait(100, p)
            if type(msg) = "roUrlEvent"
                id = msg.GetSourceIdentity().ToStr()
                if batch.DoesExist(id)
                    if msg.GetResponseCode() = 200
                        j = ParseJson(msg.GetString())
                        if j <> invalid and j.SessionName <> invalid then found.push({ url: batch[id].url, session: j.SessionName })
                    end if
                    batch.Delete(id)
                end if
            end if
        end while
        for each id in batch
            batch[id].x.AsyncCancel()
        end for
        m.top.progress = Int((host - 1) * 100 / 254)
    end while
    return { ok: found.Count() > 0, found: found, prefix: prefix, port: port }
end function
