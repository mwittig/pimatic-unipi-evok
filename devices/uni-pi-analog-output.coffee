module.exports = (env) ->

  uniPiHelper = require('../unipi-helper')(env)
  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  util = require 'util'
  rest = require('restler-promise')(Promise)
  commons = require('pimatic-plugin-commons')(env)

  # Device class representing an UniPi analog output
  class UniPiAnalogOutput extends env.devices.DimmerActuator

    # Create a new UniPiAnalogOutput device
    # @param [Object] config    device configuration
    # @param [UniPiEvokPlugin] plugin   plugin instance
    # @param [Object] lastState state information stored in database
    constructor: (@config, plugin, lastState) ->
      @debug = plugin.config.debug ? plugin.config.__proto__.debug
      @_base = commons.base @, @config.class
      @_base.debug "[UniPiAnalogOutput] initializing:", util.inspect(@config) if @debug
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
      @_updateCallback = @_getUpdateCallback()

      @attributes = _.cloneDeep(@attributes)
      @attributes.outputVoltage = {
        description: "Output Voltage"
        type: "number"
        unit: 'V'
        acronym: 'U'
      }
      super()
      plugin.updater.registerDevice 'ao', @circuit, @_updateCallback

    destroy: () ->
      plugin.updater.unregisterDevice 'ao', @circuit, @_updateCallback
      super()

    _getUpdateCallback: () ->
      return (data) =>
        @_base.debug 'status update:', util.inspect(data)
        #@_setState if data.value is 1 then true else false
        @_setDimlevel data.value * 10
        #@_base.setAttribute 'outputVoltage', data.value

    changeDimlevelTo: (newLevelPerCent) ->
      @_base.debug 'state change requested to (per cent):', newLevelPerCent
      return new Promise( (resolve, reject) =>
        rest.post(@evokDeviceUrl, _.assign({data: {value: newLevelPerCent / 10}}, @options)).then((result) =>
          uniPiHelper.parsePostResponse(result).then((data) =>
            @_setDimlevel newLevelPerCent
            @_base.setAttribute 'outputVoltage', newLevelPerCent / 10
            resolve()
          ).catch((uniPiError) =>
            @_base.error 'unable to change switch state of device', @id + ': ', uniPiError.toString()
            reject uniPiError.toString()
          )
        ).catch((result) ->
          @_base.error 'unable to change output level of device', @id + ': ', result.error.toString()
          reject result.error.toString()
        )
      )

    getOutputVoltage: () ->
      return Promise.resolve(@_outputVoltage)