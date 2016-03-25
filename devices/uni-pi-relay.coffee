module.exports = (env) ->

  uniPiHelper = require('../unipi-helper')(env)
  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  util = require 'util'
  rest = require('restler-promise')(Promise)
  commons = require('pimatic-plugin-commons')(env)

  # Device class representing an UniPi relay switch
  class UniPiRelay extends env.devices.PowerSwitch

    # Create a new UniPiRelay device
    # @param [Object] config    device configuration
    # @param [UniPiEvokPlugin] plugin   plugin instance
    # @param [Object] lastState state information stored in database
    constructor: (@config, plugin, lastState) ->
      @debug = plugin.config.debug ? plugin.config.__proto__.debug
      @_base = commons.base @, @config.class
      console.log "@debug", @debug
      @_base.debug "initializing:", util.inspect(@config) if @debug
      @id = @config.id
      @name = @config.name
      @circuit = @config.circuit
      @evokDeviceUrl = uniPiHelper.createDeviceUrl plugin.config.url, "relay", @circuit
      @options = {
        timeout: 1000 * uniPiHelper.normalize plugin.config.timeout ? plugin.config.__proto__.timeout, 5, 86400
      }
      super()
      plugin.updater.registerDevice 'relay', @circuit, @_getUpdateCallback()

    _getUpdateCallback: () ->
      return (data) =>
        @_base.debug 'status update:', util.inspect(data)
        @_setState if data.value is 1 then true else false

    getState: () ->
      return Promise.resolve @_state

    changeStateTo: (newState) ->
      @_base.debug 'state change requested to:', newState
      return new Promise( (resolve, reject) =>
        rest.post(@evokDeviceUrl, _.assign({data: {value: if newState then 1 else 0}}, @options)).then((result) =>
          uniPiHelper.parsePostResponse(result).then((data) =>
            @_setState newState
            @_base.debug 'state changed to:', newState
            resolve()
          ).catch((uniPiError) =>
            @_base.error 'unable to change switch state of device', @id + ': ', uniPiError.toString()
            reject uniPiError.toString()
          )
        ).catch((result) ->
          @_base.error 'unable to change switch state of device', @id + ': ', result.error.toString()
          reject result.error.toString()
        )
      )
