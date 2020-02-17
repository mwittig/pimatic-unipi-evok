module.exports = (env) ->

  uniPiHelper = require('../unipi-helper')(env)
  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  util = require 'util'
  rest = require('restler-promise')(Promise)
  commons = require('pimatic-plugin-commons')(env)
  UniPiRelay = require('./uni-pi-relay')(env)

  # Device class representing an UniPi digital output
  class UniPiDigitalOutput extends UniPiRelay

    # Create a new UniPiDigitalOutput device
    # @param [Object] config    device configuration
    # @param [UniPiEvokPlugin] plugin   plugin instance
    # @param [Object] lastState state information stored in database
    constructor: (@config, plugin, lastState, type='do') ->
      @id = @config.id
      @name = @config.name
      super(@config, plugin, lastState, type)

    destroy: () ->
      super()
