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
      defaultConfig = plugin.config.__proto__
      @debug = plugin.config.debug ? defaultConfig.debug
      @_base = commons.base @, @config.class
      console.log "@debug", @debug
      @_base.debug "initializing:", util.inspect(@config) if @debug
      @id = @config.id
      @name = @config.name
      @circuit = @config.circuit
      @evokDeviceUrl = uniPiHelper.createDeviceUrl plugin.config.url, "relay", @circuit
      @options = {
        timeout: 1000 * @_base.normalize plugin.config.timeout ? defaultConfig.timeout, 5, 86400
      }
      @_updateCallback = @_getUpdateCallback()

      super()
      plugin.updater.registerDevice 'relay', @circuit, @_updateCallback

    destroy: () ->
      plugin.updater.unregisterDevice 'relay', @circuit, @_updateCallback
      super()

    _getUpdateCallback: () ->
      return (data) =>
        @_base.debug 'status update:', util.inspect(data)
        @_setState if data.value is 1 then true else false

    getState: () ->
      return Promise.resolve @_state

    changeStateTo: (newState) ->
      @_base.debug 'state change requested to:', newState
      return new Promise( (resolve, reject) =>
        rest.post(
          @evokDeviceUrl,
          _.assign({data: {value: if newState then 1 else 0}}, @options)
        ).then((result) =>
          uniPiHelper.parsePostResponse(result).then((data) =>
            @_setState newState
            @_base.debug 'state changed to:', newState
            resolve()
          ).catch((uniPiError) =>
            errorText = uniPiError.toString().replace(/^Error: /, "")
            @_base.rejectWithErrorString reject,
              "Unable to change switch state: #{errorText}"
          )
        ).catch((result) =>
          errorText = result.error.toString().replace(/^Error: /, "")
          @_base.rejectWithErrorString reject,
            "Unable to change switch state: #{errorText}"
      )
    )
