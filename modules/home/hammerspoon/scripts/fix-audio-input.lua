return function(cfg)
    local log = hs.logger.new("fix-audio", "debug")
    log.i("Initializing")

    local alertSound = hs.sound.getByName("Submarine")

    local function setBetterInput()
        for _, microphoneName in ipairs(cfg.goodInputs) do
            local microphone = hs.audiodevice.findDeviceByName(microphoneName)
            if microphone then
                log.i("Setting input " .. microphoneName .. " as the default")
                microphone:setDefaultInputDevice()
                microphone:setInputVolume(100)
                alertSound:play()
                return true
            end
        end
        log.w("None of the preferred inputs are connected!")
        return false
    end

    local function audioDeviceCallback(event)
        if event == "dIn " then
            local deviceName = hs.audiodevice.defaultInputDevice():name()
            log.f("Input device has changed to %s", deviceName)

            for _, bad in ipairs(cfg.badInputs) do
                if string.find(deviceName, bad) then
                    setBetterInput()
                    break
                end
            end
        end
    end

    hs.audiodevice.watcher.setCallback(audioDeviceCallback)
    hs.audiodevice.watcher.start()

    log.i("Initialized!")
end
