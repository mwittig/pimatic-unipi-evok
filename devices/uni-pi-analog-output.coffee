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
      defaultConfig = plugin.config.__proto__
      @debug = plugin.config.debug ? defaultConfig.debug
      @_base = commons.base @, @config.class
      @_base.debug "[UniPiAnalogOutput] initializing:", util.inspect(@config) if @debug
      @id = @config.id
      @name = @config.name
      @circuit = @config.circuit
      @evokDeviceUrl = uniPiHelper.createDeviceUrl plugin.config.url, "ao", @circuit
      @options = {
        timeout: 1000 * @_base.normalize plugin.config.timeout ? defaultConfig.timeout, 5, 86400
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
        @_base.setAttribute 'outputVoltage', data.value

    changeDimlevelTo: (newLevelPerCent) ->
      @_base.debug 'output level change requested to (per cent):', newLevelPerCent
      return new Promise( (resolve, reject) =>
        rest.post(
          @evokDeviceUrl,
          _.assign({data: {value: newLevelPerCent / 10}}, @options)
        ).then((result) =>
          uniPiHelper.parsePostResponse(result).then((data) =>
            @_setDimlevel newLevelPerCent
            @_base.setAttribute 'outputVoltage', newLevelPerCent / 10
            resolve()
          ).catch((uniPiError) =>
            errorText = uniPiError.toString().replace(/^Error: /, "")
            @_base.rejectWithErrorString reject,
              "Unable to change output level: #{errorText}"
          )
        ).catch((result) =>
          errorText = result.error.toString().replace(/^Error: /, "")
          @_base.rejectWithErrorString reject,
            "Unable to change output level: #{errorText}"
        )
      )

    getOutputVoltage: () ->
      return Promise.resolve(@_outputVoltage)