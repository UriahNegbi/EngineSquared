function main()
    local payload = io.readfile(path.join(os.scriptdir(), "payload", "message.txt"))
    assert(payload and payload:trim() == "payload-ok", "plugin payload was not readable")
    print("hello-ok " .. payload:trim())
end
