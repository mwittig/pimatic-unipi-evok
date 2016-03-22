# UniPi-Evok plugin
module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  net = require 'net'
  events = require 'events'
  util = require 'util'
  rest = require('restler-promise')(Promise)
  uniPiHelper = require('./unipi-helper')(env)
  UniPiUpdateManager = require('./unipi-update-manager')(env)


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

      @framework.deviceManager.registerDeviceClass("UniPiDigitalInput", {
        configDef: deviceConfigDef.UniPiDigitalInput,
        createCallback: (config, plugin, lastState) =>
          return new UniPiDigitalInput(config, @, lastState)
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
      @debug = plugin.config.debug ? plugin.config.__proto__.debug
      env.logger.debug "[UniPiRelay] initializing:", util.inspect(@config) if @debug
      @_lastError = ""
      @id = @config.id
      @name = @config.name
      @circuit = @config.circuit
      @evokDeviceUrl = uniPiHelper.createDeviceUrl plugin.config.url, "relay", @circuit
      @options = {
        timeout: 1000 * uniPiHelper.normalize plugin.config.timeout ? plugin.config.__proto__.timeout, 5, 86400
      }
      super()
      plugin.updater.registerDevice 'relay', @circuit, @_getUpdateCallback()

    _debug: () ->
      env.logger.debug arguments... if @debug

    _getUpdateCallback: () ->
      return (data) =>
        @_debug '[UniPiRelay] status update:', util.inspect(data)
        @_setState if data.value is 1 then true else false

    getState: () ->
      return Promise.resolve @_state

    changeStateTo: (newState) ->
      @_debug '[UniPiRelay] state change requested to:', newState
      return new Promise( (resolve, reject) =>
        rest.post(@evokDeviceUrl, _.assign({data: {value: if newState then 1 else 0}}, @options)).then((result) =>
          uniPiHelper.parsePostResponse(result).then((data) =>
            @_setState newState
            @_debug '[UniPiRelay] state changed to:', newState
            resolve()
          ).catch((uniPiError) =>
            env.logger.error '[UniPiRelay] unable to change switch state of device', @id + ': ', uniPiError.toString()
            reject uniPiError.toString()
          )
        ).catch((result) ->
          env.logger.error '[UniPiRelay] unable to change switch state of device', @id + ': ', result.error.toString()
          reject result.error.toString()
        )
      )


  # Device class representing an UniPi analog output
  class UniPiAnalogOutput extends env.devices.DimmerActuator

    # Create a new UniPiAnalogOutput device
    # @param [Object] config    device configuration
    # @param [UniPiEvokPlugin] plugin   plugin instance
    # @param [Object] lastState state information stored in database
    constructor: (@config, plugin, lastState) ->
      @debug = plugin.config.debug ? plugin.config.__proto__.debug
      env.logger.debug "[UniPiAnalogOutput] initializing:", util.inspect(@config) if @debug
      @_lastError = ""
      @id = @config.id
      @name = @config.name
      @circuit = @config.circuit
      @evokDeviceUrl = uniPiHelper.createDeviceUrl plugin.config.url, "ao", @circuit
      @options = {
        timeout: 1000 * uniPiHelper.normalize plugin.config.timeout ? plugin.config.__proto__.timeout, 5, 86400
      }
      @_dimlevel = lastState?.dimlevel?.value or 0
      @_state = lastState?.state?.value or off
      @_outputVoltage = lastState?.outputVoltage?.value or @_dimlevel / 10

      @attributes = _.cloneDeep(@attributes)
      @attributes.outputVoltage = {
        description: "Output Voltage"
        type: "number"
        unit: 'V'
        acronym: 'U'
      }
      super()
      plugin.updater.registerDevice 'ao', @circuit, @_getUpdateCallback()

    _debug: () ->
      env.logger.debug arguments... if @debug

    _getUpdateCallback: () ->
      return (data) =>
        @_debug '[UniPiAnalogOutput] status update:', util.inspect(data)
        #@_setState if data.value is 1 then true else false
        @_setDimlevel data.value * 10
        #@_setAttribute 'outputVoltage', data.value

    _setAttribute: (attributeName, value) ->
      if @['_' + attributeName] isnt value
        @['_' + attributeName] = value
        @emit attributeName, value

    changeDimlevelTo: (newLevelPerCent) ->
      @_debug '[UniPiAnalogOutput] state change requested to (per cent):', newLevelPerCent
      return new Promise( (resolve, reject) =>
        rest.post(@evokDeviceUrl, _.assign({data: {value: newLevelPerCent / 10}}, @options)).then((result) =>
          uniPiHelper.parsePostResponse(result).then((data) =>
            @_setDimlevel newLevelPerCent
            @_setAttribute 'outputVoltage', newLevelPerCent / 10
            resolve()
          ).catch((uniPiError) =>
            env.logger.error '[UniPiAnalogOutput] unable to change switch state of device', @id + ': ', uniPiError.toString()
            reject uniPiError.toString()
          )
        ).catch((result) ->
          env.logger.error '[UniPiAnalogOutput] unable to change output level of device', @id + ': ', result.error.toString()
          reject result.error.toString()
        )
      )

    getOutputVoltage: () ->
      return Promise.resolve(@_outputVoltage)


  # Device class representing an UniPi analog input
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
      @debug = plugin.config.debug ? plugin.config.__proto__.debug
      env.logger.debug '[UniPiAnalogInput] initializing:', util.inspect(@config) if @debug
      @_inputVoltage = lastState?.inputVoltage?.value or 0.0
      @id = @config.id
      @name = @config.name
      @circuit = @config.circuit
      @_lastError = ""

      super()
      plugin.updater.registerDevice 'ai', @circuit, @_getUpdateCallback()

    _setAttribute: (attributeName, value) ->
      if @['_' + attributeName] isnt value
        @['_' + attributeName] = value
        @emit attributeName, value

    _getUpdateCallback: () ->
      return (data) =>
        env.logger.debug '[UniPiAnalogInput] status update:', util.inspect(data) if @debug
        @_setAttribute "inputVoltage", data.value

    getInputVoltage: () ->
      return Promise.resolve(@_inputVoltage)


  # Device class representing an UniPi digital output
  class UniPiDigitalInput extends env.devices.ContactSensor
    # Create a new UniPiDigitalInput device
    # @param [Object] config    device configuration
    # @param [UniPiEvokPlugin] plugin   plugin instance
    # @param [Object] lastState state information stored in database
    constructor: (@config, plugin, lastState) ->
      @debug = plugin.config.debug ? plugin.config.__proto__.debug
      env.logger.debug '[UniPiDigitalInput] initializing:', util.inspect(@config) if @debug
      @_contact = lastState?.contact?.value or 0.0
      @id = @config.id
      @name = @config.name
      @circuit = @config.circuit
      @_lastError = ""

      super()
      plugin.updater.registerDevice 'input', @circuit, @_getUpdateCallback()

    _setAttribute: (attributeName, value) ->
      if @['_' + attributeName] isnt value
        @['_' + attributeName] = value
        @emit attributeName, value

    _getUpdateCallback: () ->
      return (data) =>
        env.logger.debug '[UniPiDigitalInput] status update:', util.inspect(data) if @debug
        @_setAttribute "contact", if data.value is 1 then true else false

    getContact: () ->
      return Promise.resolve(@_contact)


  # Device class representing an UniPi temperature sensor
  class UniPiTemperature extends env.devices.TemperatureSensor

    # Create a new UniPiTemperature device
    # @param [Object] config    device configuration
    # @param [UniPiEvokPlugin] plugin   plugin instance
    # @param [Object] lastState state information stored in database
    constructor: (@config, plugin, lastState) ->
      @debug = plugin.config.debug ? plugin.config.__proto__.debug
      env.logger.debug '[UniPiTemperature] initializing:', util.inspect(@config) if @debug
      @_temperature = lastState?.temperature?.value or 0.0
      @id = @config.id
      @name = @config.name
      @circuit = @config.circuit
      @_lastError = ""

      super()
      plugin.updater.registerDevice 'temp', @circuit, @_getUpdateCallback()

    _setAttribute: (attributeName, value) ->
      if @['_' + attributeName] isnt value
        @['_' + attributeName] = value
        @emit attributeName, value
      
    _getUpdateCallback: () ->                                          
      return (data) =>
        env.logger.debug '[UniPiTemperature] status update:', util.inspect(data) if @debug
        @_setAttribute "temperature", data.value

    getTemperature: () ->
      return Promise.resolve(@_temperature)

  # ###Finally
  # Create a instance of my plugin
  myPlugin = new UniPiEvokPlugin
  # and return it to the framework.
  return myPlugin