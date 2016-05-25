module.exports = (env) ->

  uniPiHelper = require('../unipi-helper')(env)
  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  util = require 'util'
  rest = require('restler-promise')(Promise)
  commons = require('pimatic-plugin-commons')(env)

  # Device class representing an UniPi temperature sensor
  class UniPiTemperature extends env.devices.TemperatureSensor

    # Create a new UniPiTemperature device
    # @param [Object] config    device configuration
    # @param [UniPiEvokPlugin] plugin   plugin instance
    # @param [Object] lastState state information stored in database
    constructor: (@config, plugin, lastState) ->
      @debug = plugin.config.debug ? plugin.config.__proto__.debug
      @_base = commons.base @, @config.class
      @_base.debug 'initializing:', util.inspect(@config) if @debug
      @_temperature = lastState?.temperature?.value or 0.0
      @id = @config.id
      @name = @config.name
      @circuit = @config.circuit
      @_updateCallback = @_getUpdateCallback()

      super()
      plugin.updater.registerDevice 'temp', @circuit, @_updateCallback

    destroy: () ->
      plugin.updater.unregisterDevice 'temp', @circuit, @_updateCallback
      super()

    _getUpdateCallback: () ->
      return (data) =>
        @_base.debug 'status update:', util.inspect(data) if @debug
        @_base.setAttribute "temperature", data.value

    getTemperature: () ->
      return Promise.resolve(@_temperature)

