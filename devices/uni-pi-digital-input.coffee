module.exports = (env) ->

  uniPiHelper = require('../unipi-helper')(env)
  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  util = require 'util'
  rest = require('restler-promise')(Promise)
  commons = require('pimatic-plugin-commons')(env)

  # Device class representing an UniPi digital output
  class UniPiDigitalInput extends env.devices.ContactSensor
    # Create a new UniPiDigitalInput device
    # @param [Object] config    device configuration
    # @param [UniPiEvokPlugin] plugin   plugin instance
    # @param [Object] lastState state information stored in database
    constructor: (@config, plugin, lastState) ->
      @debug = plugin.config.debug ? plugin.config.__proto__.debug
      @_base = commons.base @, @config.class
      @_base.debug 'initializing:', util.inspect(@config) if @debug
      @_contact = lastState?.contact?.value or 0.0
      @id = @config.id
      @name = @config.name
      @circuit = @config.circuit
      @_updateCallback = @_getUpdateCallback()

      super()
      plugin.updater.registerDevice 'input', @circuit, @_updateCallback

    destroy: () ->
      plugin.updater.unregisterDevice 'input', @circuit, @_updateCallback
      super()

    _getUpdateCallback: () ->
      return (data) =>
        @_base.debug 'status update:', util.inspect(data) if @debug
        @_base.setAttribute "contact", if data.value is 1 then true else false

    getContact: () ->
      return Promise.resolve(@_contact)
