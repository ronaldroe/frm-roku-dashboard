sub Main()
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene("MainScene")
    screen.Show()

    app = CreateObject("roAppInfo")
    secs = Val(app.GetValue("refresh_seconds"))
    if secs < 2 then secs = 5
    scene.config = { url: app.GetValue("frm_url"), interval: secs }

    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.IsScreenClosed() then return
    end while
end sub
