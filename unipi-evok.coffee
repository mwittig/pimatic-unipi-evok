# UniPi-Evok plugin
module.exports = (env) ->

  _ = env.require 'lodash'
  UniPiUpdateManager = require('./unipi-update-manager')(env)
  commons = require('pimatic-plugin-commons')(env)
  deviceConfigTemplates = {
    "relay": {
      id: "unipi-relay-"
      name: "UniPi Relay "
      class: "UniPiRelay"
    }
    "do": {
      "id": "unipi-digital-output-"
      "class": "UniPiDigitalOutput"
      "name": "UniPi Digital Output "
    }
    "ai": {
      "id": "unipi-analog-input-"
      "class": "UniPiAnalogInput"
      "name": "UniPi Analog Input "
    }
    "ao": {
      "id": "unipi-analog-output-"
      "class": "UniPiAnalogOutput"
      "name": "UniPi Analog Output "
    }
    "input": {
      "id": "unipi-digital-input-"
      "class": "UniPiDigitalInput"
      "name": "UniPi Digital Input "
    }
    "temp": {
      "id": "unipi-temperature-"
      "class": "UniPiTemperature"
      "name": "UniPi Temperature "
    }
  }

  # ###UniPiEvokPlugin class
  class UniPiEvokPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      @updater = new UniPiUpdateManager(@config, @)
      @debug = @config.debug || false
      @_base = commons.base @, 'Plugin'

      # register devices
      deviceConfigDef = require("./device-config-schema")
      for key, device of deviceConfigTemplates
        do (key, device) =>
          className = device.class
          # convert camel-case classname to kebap-case filename
          filename = className.replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase()
          classType = require('./devices/' + filename)(env)
          @_base.debug "Registering device class #{className}"
          @framework.deviceManager.registerDeviceClass(className, {
            configDef: deviceConfigDef[className],
            createCallback: (config, lastState) =>
              return new classType(config, @, lastState)
          })

      # auto-discovery
      @framework.deviceManager.on('discover', (eventData) =>
        @framework.deviceManager.discoverMessage 'pimatic-unipi-evok', 'Searching for devices'

        @updater.queryAllDevices().then((result) =>
          for obj in result
            if deviceConfigTemplates[obj.dev]?
              device = _.assign({}, deviceConfigTemplates[obj.dev])
              device.id += obj.circuit
              device.name += obj.circuit
              device.circuit = obj.circuit
              matched = @framework.deviceManager.devicesConfig.some (element, iterator) ->
                element.class is device.class and element.circuit is device.circuit

              if not matched
                process.nextTick(
                  @_discoveryCallbackHandler('pimatic-unipi-evok', device.name, device)
                )
        )
      )

    _discoveryCallbackHandler: (pluginName, deviceName, deviceConfig) ->
      return () =>
        @framework.deviceManager.discoveredDevice pluginName, deviceName, deviceConfig


  # ###Finally
  # Create a instance of plugin
  return new UniPiEvokPlugin