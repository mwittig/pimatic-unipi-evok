# UniPi-Evok plugin
module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  net = require 'net'
  events = require 'events'
  url = require 'url'
  util = require 'util'
  WebSocket = require 'ws'
  rest = require('restler-promise')(Promise)

  # UniPi helper functions
  uniPiHelper =
    createDeviceUrl: (baseUrl, deviceType, circuit) ->
      urlObject = url.parse baseUrl, false, true
      urlObject.pathname = "rest/" + deviceType + "/" + circuit
      return url.format urlObject

    getErrorResult: (data) ->
      errorMessage = uniPiHelper.getPath data, 'errors.__all__'
      console.log data, errorMessage
      unless _.isString errorMessage
        errorMessage = "failed"
      return new Error errorMessage

    normalize: (value, lowerRange, upperRange) ->
      if upperRange
        return Math.min (Math.max value, lowerRange), upperRange
      else
        return Math.max value lowerRange

    # helper function to get the object path as older versions of lodash do not support this
    getPath: (obj, path) ->
      return undefined if not _.isObject obj or not _.isString path
      keys = path.split '.'
      for key in keys
        if not _.isObject(obj) or not obj.hasOwnProperty(key)
          return undefined
        obj = obj[key]
      return obj

  class UniPiUpdateManager extends events.EventEmitter

    constructor: (@config, plugin) ->
      @baseURL = plugin.config.url
      urlObject = url.parse @baseURL, false, true
      urlObject.pathname = "ws"
      url.protocol = if url.protocol is "https:" then "wss:" else "ws:"
      @wsURL = url.format urlObject
      env.logger.debug "[UniPiUpdateManager] initializing web socket: ", @wsURL
      @ws = new WebSocket(@wsURL);
      super()

      @ws.on('message', (message) =>
        env.logger.debug "[UniPiUpdateManager] received update:", message
        try
          json = JSON.parse message
          console.log 'received: %s', message
          @emit json.dev + json.circuit, json if json.dev and json.circuit
        catch error
          env.logger.error "[UniPiUpdateManager] exception caught:", error.toString()
      )

      @ws.on('error', (error) =>
      )
    registerDevice: (deviceType, circuit, callback) =>
      @addListener deviceType + circuit, callback
      restDeviceType = deviceType
      unless restDeviceType in ['relay', 'di', 'input', 'ai', 'analoginput', 'ao', 'analogoutput', 'sensor']
        restDeviceType = 'sensor'
      @getDeviceStatus restDeviceType, circuit

    getDeviceStatus: (deviceType, circuit) =>
      urlObject = url.parse @baseURL, false, true
      urlObject.pathname = "rest/" + deviceType + "/" + circuit
      env.logger.error "[UniPiUpdateManager] requesting status for device:", url.format(urlObject)
      rest.get(url.format(urlObject)).then((result) =>
        console.log("COMPLETE", result.data)
        try
          json = JSON.parse result.data
          unless _.isUndefined(json.dev) or _.isUndefined(json.circuit)
            @emit json.dev + json.circuit, json
          else
            env.logger.error '[UniPiUpdateManager] unable to get device status, invalid data: ', result.data
        catch error
          env.logger.error '[UniPiUpdateManager] unable to get device status, exception caught: ', error.toString()

      ).catch((error)  =>
        console.log("ERROR", error.error)
      )


  # ###UniPiEvokPlugin class
  class UniPiEvokPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      @updater = new UniPiUpdateManager(@config, @)

      # register devices
      deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass("UniPiRelay", {
        configDef: deviceConfigDef.UniPiRelay,
        createCallback: (config, plugin, lastState) =>
          return new UniPiRelay(config, @, lastState)
      })

      @framework.deviceManager.registerDeviceClass("UniPiAnalogOutput", {
        configDef: deviceConfigDef.UniPiAnalogOutput,
        createCallback: (config, plugin, lastState) =>
          return new UniPiAnalogOutput(config, @, lastState)
      })

      @framework.deviceManager.registerDeviceClass("UniPiAnalogInput", {
        configDef: deviceConfigDef.UniPiAnalogInput,
        createCallback: (config, plugin, lastState) =>
          return new UniPiAnalogInput(config, @, lastState)
      })

      @framework.deviceManager.registerDeviceClass("UniPiTemperature", {
        configDef: deviceConfigDef.UniPiTemperature,
        createCallback: (config, plugin, lastState) =>
          return new UniPiTemperature(config, @, lastState)
      })

  # Device class representing an UniPi relay switch
  class UniPiRelay extends env.devices.PowerSwitch

    # Create a new UniPiRelay device
    # @param [Object] config    device configuration
    # @param [UniPiEvokPlugin] plugin   plugin instance
    # @param [Object] lastState state information stored in database
    constructor: (@config, plugin, lastState) ->
      env.logger.debug "[UniPiRelay] initializing: ", util.inspect(config)
      @debug = plugin.config.debug
      @_lastError = ""
      @id = config.id
      @name = config.name
      @circuit = config.circuit
      @evokDeviceUrl = uniPiHelper.createDeviceUrl plugin.config.url, "relay", @circuit
      @options = {
        timeout: 1000 * uniPiHelper.normalize plugin.config.timeout, 10, 86400
      }
      super()
      plugin.updater.registerDevice 'relay', @circuit, @_getUpdateCallback()

    _getUpdateCallback: () ->
      return (data) =>
        env.logger.debug '[UniPiRelay] status update:', util.inspect(data)
        @_setState if data.value is 1 then true else false

    getState: () ->
      return Promise.resolve @_state

    changeStateTo: (newState) ->
      env.logger.debug '[UniPiRelay] state change requested to:', newState
      return new Promise( (resolve, reject) =>
        rest.post(@evokDeviceUrl, {data: {value: if newState then 1 else 0}}, {}).then((result) =>
          try
            json = JSON.parse result.data
            if json.success
              @_setState newState
              resolve()
            else
              uniPiError = uniPiHelper.getErrorResult json
              env.logger.error '[UniPiRelay] unable to change switch state of device', @id + ': ', uniPiError.toString()
              reject uniPiError
          catch err
            env.logger.error '[UniPiRelay] unable to change switch state of device', @id + ': ', err.toString()
            reject err
        ).catch((result) ->
          env.logger.error '[UniPiRelay] unable to change switch state of device', @id + ': ', result.error.toString()
          reject result.error
        )
      )

  # Device class representing an UniPi analog output
  class UniPiAnalogOutput extends env.devices.DimmerActuator
#    attributes:
#      outputVoltage:
#        description: "Output Voltage"
#        type: "number"
#        unit: 'V'
#        acronym: 'U'

    # Create a new UniPiAnalogOutput device
    # @param [Object] config    device configuration
    # @param [UniPiEvokPlugin] plugin   plugin instance
    # @param [Object] lastState state information stored in database
    constructor: (@config, plugin, lastState) ->
      env.logger.debug "[UniPiAnalogOutput] initializing: ", util.inspect(config)
      @debug = plugin.config.debug
      @_lastError = ""
      @id = config.id
      @name = config.name
      @circuit = config.circuit
      @evokDeviceUrl = uniPiHelper.createDeviceUrl plugin.config.url, "ao", @circuit
      @options = {
        timeout: 1000 * uniPiHelper.normalize plugin.config.timeout, 10, 86400
      }
      @_dimlevel = lastState?.dimlevel?.value or 0
      @_state = lastState?.state?.value or off
      @_outputVoltage = lastState?.outputVoltage?.value or @_dimlevel / 10
      super()
      plugin.updater.registerDevice 'ao', @circuit, @_getUpdateCallback()

    _getUpdateCallback: () ->
      return (data) =>
        env.logger.debug '[UniPiAnalogOutput] status update:', util.inspect(data)
        #@_setState if data.value is 1 then true else false
        @_setDimlevel data.value * 10
        #@_setAttribute 'outputVoltage', data.value

    _setAttribute: (attributeName, value) ->
      if @['_' + attributeName] isnt value
        @['_' + attributeName] = value
        @emit attributeName, value

    changeDimlevelTo: (newLevelPerCent) ->
      env.logger.debug '[UniPiAnalogOutput] state change requested to (per cent):', newLevelPerCent
      return new Promise( (resolve, reject) =>
        rest.post(@evokDeviceUrl, {data: {value: newLevelPerCent / 10}}, {}).then((result) =>
          try
            json = JSON.parse result.data
            if json.success
              @_setDimlevel newLevelPerCent
              #@_setAttribute 'outputVoltage', newLevelPerCent / 10
              resolve()
            else
              uniPiError = uniPiHelper.getErrorResult json
              env.logger.error '[UniPiAnalogOutput] unable to change output level of device', @id + ': ', uniPiError.toString()
              reject uniPiError
          catch err
            env.logger.error '[UniPiAnalogOutput] unable to change output level of device', @id + ': ', err.toString()
            reject err
        ).catch((result) ->
          env.logger.error '[UniPiAnalogOutput] unable to change output level of device', @id + ': ', result.error.toString()
          reject result.error
        )
      )

    getOutputVoltage: () ->
      return Promise.resolve(@_outputVoltage)

  class UniPiAnalogInput extends env.devices.Device

    attributes:
      inputVoltage:
        description: "Input Voltage"
        type: "number"
        unit: 'V'
        acronym: 'U'
    
    # Create a new UniPiAnalogInput device
    # @param [Object] config    device configuration
    # @param [UniPiEvokPlugin] plugin   plugin instance
    # @param [Object] lastState state information stored in database
    constructor: (@config, plugin, lastState) ->
      env.logger.debug '[UniPiAnalogInput]', util.inspect(config), lastState
      @debug = plugin.config.debug
      @_inputVoltage = lastState?.inputVoltage?.value or 0.0
      @id = config.id
      @name = config.name
      @circuit = config.circuit
      @_lastError = ""

      super()
      plugin.updater.registerDevice 'ai', @circuit, @_getUpdateCallback()

    _setAttribute: (attributeName, value) ->
      if @['_' + attributeName] isnt value
        @['_' + attributeName] = value
        @emit attributeName, value

    _getUpdateCallback: () ->
      return (data) =>
        env.logger.debug '[UniPiAnalogInput] status update:', util.inspect(data)
        @_setAttribute "inputVoltage", data.value

    getInputVoltage: () ->
      return Promise.resolve(@_inputVoltage)
      
  class UniPiTemperature extends env.devices.TemperatureSensor

    # Create a new UniPiTemperature device
    # @param [Object] config    device configuration
    # @param [UniPiEvokPlugin] plugin   plugin instance
    # @param [Object] lastState state information stored in database
    constructor: (@config, plugin, lastState) ->
      env.logger.debug '[UniPiTemperature]', util.inspect(config), lastState
      @debug = plugin.config.debug
      @_temperature = lastState?.temperature?.value or 0.0
      @id = config.id
      @name = config.name
      @circuit = config.circuit
      @_lastError = ""

      super()
      plugin.updater.registerDevice 'temp', @circuit, @_getUpdateCallback()

    _setAttribute: (attributeName, value) ->
      if @['_' + attributeName] isnt value
        @['_' + attributeName] = value
        @emit attributeName, value
      
    _getUpdateCallback: () ->                                          
      return (data) =>                                                
        env.logger.debug '[UniPiTemperature] status update:', util.inspect(data)
        @_setAttribute "temperature", data.value

    getTemperature: () ->
      return Promise.resolve(@_temperature)

  # ###Finally
  # Create a instance of my plugin
  myPlugin = new UniPiEvokPlugin
  # and return it to the framework.
  return myPlugin