# #UniPi-Evok plugin

module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  net = require 'net'
  url = require 'url'
  rest = require('restler-promise')(Promise)


  # ###UniPiEvokPlugin class
  class UniPiEvokPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      # register devices
      deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass("UniPiRelay", {
        configDef: deviceConfigDef.UniPiRelay,
        createCallback: (config, plugin, lastState) =>
          return new UniPiRelay(config, @, lastState)
      })



  class UniPiRelay extends env.devices.PowerSwitch
    # Initialize device by reading entity definition from middleware
    constructor: (@config, plugin, lastState) ->
      @debug = plugin.config.debug
      env.logger.debug("UniPiRelay Initialization") if @debug
      @id = config.id
      @name = config.name
      @circuit = config.circuit
      @options = {
        timeout: 1000 * @_normalize plugin.config.timeout, 10, 86400
      }
      urlObject = url.parse plugin.config.url, false, true
      urlObject.pathname = "rest/relay/" + @circuit
      @_urlString = url.format urlObject
      @_lastError = ""
      super()

    _normalize: (value, lowerRange, upperRange) ->
      if upperRange
        return Math.min (Math.max value, lowerRange), upperRange
      else
        return Math.max value lowerRange

    _setAttribute: (attributeName, value) ->
      if @[attributeName] isnt value
        @[attributeName] = value
        @emit attributeName, value

    getState: () ->
        return Promise.resolve @_state

    changeStateTo: (state) ->
      return  rest.post(@_urlString, {data: {value: if state then 1 else 0}}, {}).then(() =>
        @_setState(state)

        return Promise.resolve()
      ).catch((result) ->
        env.logger.error("Unable to change switch state of device " + id + ": " + result.error.toString())
      )

  # ###Finally
  # Create a instance of my plugin
  myPlugin = new UniPiEvokPlugin
  # and return it to the framework.
  return myPlugin