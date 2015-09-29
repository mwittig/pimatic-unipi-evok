# Class UniPiUpdateManager
module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  net = require 'net'
  events = require 'events'
  url = require 'url'
  util = require 'util'
  WebSocket = require 'ws'
  rest = require('restler-promise')(Promise)
  uniPiHelper = require('./unipi-helper')(env)

  class UniPiUpdateManager extends events.EventEmitter

    constructor: (@config, plugin) ->
      @debug = plugin.config.debug ? false
      @baseURL = plugin.config.url
      urlObject = url.parse @baseURL, false, true
      urlObject.pathname = "ws"
      url.protocol = if url.protocol is "https:" then "wss:" else "ws:"
      @wsURL = url.format urlObject
      @ws = null
      @_connectTimer = null
      @_heartbeatTimer = null
      @_connectWebSocket()
      super()

    _debugLog: () ->
      env.logger.debug arguments... if @debug

    _getWebSocketMessageHandler: () ->
      return (message) =>
        @_debugLog "[UniPiUpdateManager] received update:", message
        try
          json = JSON.parse message
          @emit json.dev + json.circuit, json if json.dev? and json.circuit?
        catch error
          env.logger.error "[UniPiUpdateManager] exception caught:", error.toString()

    _getWebSocketOpenHandler: () ->
      return () =>
        @_debugLog "[UniPiUpdateManager] Web Socket Opened"
        @_stopReconnectTimer()
        @_startHeartbeatTimer()
        @getStatusForAllDevices()

    _getWebSocketCloseHandler: () ->
      return () =>
        @_debugLog "[UniPiUpdateManager] Web Socket Closed"
        @_startReconnectTimer()
        @_stopHeartbeatTimer()

    _getWebSocketErrorHandler: () ->
      return (error) =>
        env.logger.error "[UniPiUpdateManager] Web Socket Error:", error.toString()
        @_startReconnectTimer()
        @_stopHeartbeatTimer()

    _startReconnectTimer: () ->
      @_debugLog "[UniPiUpdateManager] Attempting to reconnect Web Socket in 20s"
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
      @_debugLog "[UniPiUpdateManager] Starting Web Socket Heartbeat"
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
        @_debugLog "[UniPiUpdateManager] Heartbeat"
        @ws.send(" ", (error) =>
          if (error)
            @_debugLog "[UniPiUpdateManager] Heartbeat Error", error
            @_stopHeartbeatTimer()
            @_startReconnectTimer()
        )

    _connectWebSocket: () ->
      if not @ws? or @ws.readyState isnt WebSocket.OPEN
        @_debugLog "[UniPiUpdateManager] Connect Web Socket to: ", @wsURL
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
      @_debugLog "[UniPiUpdateManager] requesting status for all devices:", url.format(urlObject)
      rest.get(url.format(urlObject)).then((result) =>
        @_debugLog "[UniPiUpdateManager] response (status for all devices):", result.data
        uniPiHelper.parseGetResponse(result).then((json) =>
          if _.isArray(json)
            for obj in json
              @emit obj.dev + obj.circuit, obj
          else
            env.logger.error '[UniPiUpdateManager] unable to get device status, invalid data: ', result.data
        ).catch((error) =>
          env.logger.error '[UniPiUpdateManager] unable to get device status, exception caught: ', error.toString()
        )
      ).catch((errorResult)  =>
        env.logger.error '[UniPiUpdateManager] unable to get device status, exception caught: ',
          errorResult.error.toString()
      )

    getStatusForDevice: (deviceType, circuit) =>
      urlObject = url.parse @baseURL, false, true
      urlObject.pathname = "rest/" + deviceType + "/" + circuit
      @_debugLog "[UniPiUpdateManager] requesting status for device:", url.format(urlObject)
      rest.get(url.format(urlObject)).then((result) =>
        uniPiHelper.parseGetResponse(result).then((json) =>
          unless _.isUndefined(json.dev) or _.isUndefined(json.circuit)
            @_debugLog "[UniPiUpdateManager] status:", json.dev + json.circuit, json
            @emit json.dev + json.circuit, json
          else
            env.logger.error '[UniPiUpdateManager] unable to get device status, invalid data: ', result.data
        ).catch((error) =>
          env.logger.error '[UniPiUpdateManager] unable to get device status, exception caught: ', error.toString()
        )
      ).catch((errorResult) =>
        env.logger.error '[UniPiUpdateManager] unable to get device status, exception caught: ',
          errorResult.error.toString()
      )