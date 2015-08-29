module.exports = {
  title: "pimatic-unipi-evok plugin config options"
  type: "object"
  properties:
    debug:
      description: "Debug mode. Writes debug message to the pimatic log"
      type: "boolean"
      default: false
    url:
      description: "URL of the Evok Web Server"
      type: "string"
    timeout:
      description: "Timeout in seconds for HTTP REST Requests, value range [10-86400]"
      type: "number"
      default: 20
}