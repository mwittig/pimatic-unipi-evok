module.exports = (env) ->

  uniPiHelper = require('../unipi-helper')(env)
  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  util = require 'util'
  rest = require('restler-promise')(Promise)
  commons = require('pimatic-plugin-commons')(env)

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
      @_base = commons.base @, @config.class
      env.logger.debug 'initializing:', util.inspect(@config) if @debug
      @_inputVoltage = lastState?.inputVoltage?.value or 0.0
      @id = @config.id
      @name = @config.name
      @circuit = @config.circuit
      @_updateCallback = @_getUpdateCallback()

      super()
      plugin.updater.registerDevice 'ai', @circuit, @_updateCallback

    destroy: () ->
      plugin.updater.unregisterDevice 'ai', @circuit, @_updateCallback
      super()

    _getUpdateCallback: () ->
      return (data) =>
        env.logger.debug 'status update:', util.inspect(data) if @debug
        @_base.setAttribute "inputVoltage", data.value

    getInputVoltage: () ->
      return Promise.resolve(@_inputVoltage)
