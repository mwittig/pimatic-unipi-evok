module.exports = (env) ->

  Promise = env.require 'bluebird'
  url = require 'url'
  _ = env.require 'lodash'


  # UniPi helper functions
  uniPiHelper =
    createDeviceUrl: (baseUrl, deviceType, circuit) ->
      urlObject = url.parse baseUrl, false, true
      urlObject.pathname = "rest/" + deviceType + "/" + circuit
      return url.format urlObject

    getErrorResult: (data) ->
      errorMessage = uniPiHelper.getPath data, 'errors.__all__'
      unless _.isString errorMessage
        errorMessage = "failed"
      return new Error errorMessage

    normalize: (value, lowerRange, upperRange) ->
      if upperRange
        return Math.min (Math.max value, lowerRange), upperRange
      else
        return Math.max value lowerRange

    # helper function to get the object path as older versions of lodash do not support this
    getPath: (obj, path) ->
      return undefined if not _.isObject obj or not _.isString path
      keys = path.split '.'
      for key in keys
        if not _.isObject(obj) or not obj.hasOwnProperty(key)
          return undefined
        obj = obj[key]
      return obj

    parseGetResponse: (result) ->
      try
        json = JSON.parse result.data
        return Promise.resolve json
      catch err
        return Promise.reject err

    parsePostResponse: (result) ->
      uniPiHelper.parseGetResponse(result).then((json) =>
        if json.success
          return Promise.resolve json
        else
          uniPiError = uniPiHelper.getErrorResult json
          return Promise.reject uniPiError
      ).catch((error) =>
        return Promise.reject error
      )


  return uniPiHelper