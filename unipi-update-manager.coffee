# Class UniPiUpdateManager
module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  events = require 'events'
  url = require 'url'
  util = require 'util'
  WebSocket = require 'ws'
  rest = require('restler-promise')(Promise)
  uniPiHelper = require('./unipi-helper')(env)
  commons = require('pimatic-plugin-commons')(env)

  class UniPiUpdateManager extends events.EventEmitter

    constructor: (@config, plugin) ->
      @debug = plugin.config.debug ? plugin.config.__proto__.debug
      @_base = commons.base @, 'UniPiUpdateManager'
      @baseURL = plugin.config.url
      urlObject = url.parse @baseURL, false, true
      urlObject.pathname = "ws"
      url.protocol = if url.protocol is "https:" then "wss:" else "ws:"
      @wsURL = url.format urlObject
      @options = {
        timeout: 1000 * uniPiHelper.normalize plugin.config.timeout ? plugin.config.__proto__.timeout, 5, 86400
      }
      @ws = null
      @_lastError = ''
      @_connectTimer = null
      @_heartbeatTimer = null
      @_connectWebSocket()
      super()

    _getWebSocketMessageHandler: () ->
      return (message) =>
        @_base.debug "received update:", message
        try
          json = JSON.parse message
          @emit json.dev + json.circuit, json if json.dev? and json.circuit?
          @_lastError = ''
        catch error
          @_base.error "exception caught:", error.toString()

    _getWebSocketOpenHandler: () ->
      return () =>
        @_base.debug "Web Socket Opened"
        @_lastError = ''
        @_stopReconnectTimer()
        @_startHeartbeatTimer()
        @getStatusForAllDevices()

    _getWebSocketCloseHandler: () ->
      return () =>
        @_base.error "Web Socket Closed"
        @_startReconnectTimer()
        @_stopHeartbeatTimer()

    _getWebSocketErrorHandler: () ->
      return (error) =>
        @_base.error 'Web Socket Error: ' + error.toString()
        @_startReconnectTimer()
        @_stopHeartbeatTimer()

    _startReconnectTimer: () ->
      @_base.debug "Attempting to reconnect Web Socket in 20s"
      @_stopReconnectTimer()
      @_connectTimer = setTimeout(( =>
        @_connectTimer = null
        @_connectWebSocket()
      ), 20000)

    _stopReconnectTimer: () ->
      if @_connectTimer?
        clearTimeout(@_connectTimer)
        @_connectTimer = null

    _startHeartbeatTimer: () ->
      @_base.debug "Starting Web Socket Heartbeat"
      @_stopReconnectTimer()
      @_heartbeatTimer = setTimeout(( =>
        @_heartbeatTimer = null
        @_heartbeatWebSocket()
      ), 20000)

    _stopHeartbeatTimer: () ->
      if @_heartbeatTimer?
        clearTimeout(@_heartbeatTimer)
        @_heartbeatTimer = null

    _heartbeatWebSocket: () ->
      @_startHeartbeatTimer()
      if @ws?
        @_base.debug "Heartbeat"
        @ws.send(" ", (error) =>
          if (error)
            @_base.debug "Heartbeat Error", error
            @_stopHeartbeatTimer()
            @_startReconnectTimer()
        )

    _connectWebSocket: () ->
      if not @ws? or @ws.readyState isnt WebSocket.OPEN
        @_base.debug "Connect Web Socket to: ", @wsURL
        @_disconnectWebSocket()
        @ws = new WebSocket(@wsURL)
        @ws.addListener('open', @_getWebSocketOpenHandler())
        @ws.addListener('message', @_getWebSocketMessageHandler())
        @ws.addListener('close', @_getWebSocketCloseHandler())
        @ws.addListener('error', @_getWebSocketErrorHandler())

    _disconnectWebSocket: () ->
      if @ws?
        @ws.removeListener('open', @_getWebSocketOpenHandler())
        @ws.removeListener('message', @_getWebSocketMessageHandler())
        @ws.removeListener('close', @_getWebSocketCloseHandler())
        # don't remove the error callback as it might be hit during close
        @ws.terminate()
        @ws = null

    registerDevice: (deviceType, circuit, callback) =>
      @addListener deviceType + circuit, callback
      restDeviceType = deviceType
      unless restDeviceType in ['relay', 'di', 'input', 'ai', 'analoginput', 'ao', 'analogoutput', 'sensor']
        restDeviceType = 'sensor'
      @getStatusForDevice restDeviceType, circuit

    getStatusForAllDevices: () =>
      urlObject = url.parse @baseURL, false, true
      urlObject.pathname = "rest/all"
      @_base.debug "requesting status for all devices:", url.format(urlObject)
      rest.get(url.format(urlObject), @options).then((result) =>
        @_base.debug "response (status for all devices):", result.data
        uniPiHelper.parseGetResponse(result).then((json) =>
          if _.isArray(json)
            @_lastError = ''
            for obj in json
              @emit obj.dev + obj.circuit, obj
          else
            @_base.error 'unable to get device status, invalid data: ', result.data
        ).catch((error) =>
          @_base.error 'unable to get device status, exception caught: ', error.toString()
        )
      ).catch((errorResult)  =>
        @_base.error 'unable to get device status, exception caught: ',
          errorResult.error.toString()
      )

    getStatusForDevice: (deviceType, circuit) =>
      urlObject = url.parse @baseURL, false, true
      urlObject.pathname = "rest/" + deviceType + "/" + circuit
      @_base.debug "requesting status for device:", url.format(urlObject)
      rest.get(url.format(urlObject), @options).then((result) =>
        uniPiHelper.parseGetResponse(result).then((json) =>
          unless _.isUndefined(json.dev) or _.isUndefined(json.circuit)
            @_lastError = ''
            @_base.debug "status:", json.dev + json.circuit, json
            @emit json.dev + json.circuit, json
          else
            @_base.error 'unable to get device status, invalid data: ', result.data
        ).catch((error) =>
          @_base.error 'unable to get device status, exception caught: ', error.toString()
        )
      ).catch((errorResult) =>
        @_base.error 'unable to get device status, exception caught: ',
          errorResult.error.toString()
      )