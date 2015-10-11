module.exports = {
  title: "pimatic-probe device config schemas"
  UniPiRelay: {
    title: "UniPi Relay"
    description: "UniPi Relay"
    type: "object"
    extensions: ["xConfirm", "xLink", "xOnLabel", "xOffLabel"]
    properties:
      circuit:
        description: "The Relay circuit address (a number string between 1 and 8)"
        type: "string"
  },
  UniPiAnalogOutput: {
    title: "UniPi Analog Output"
    description: "UniPi Analog Output"
    type: "object"
    extensions: ["xConfirm", "xLink"]
    properties:
      circuit:
        description: "The Analog Output circuit id"
        type: "string"
        default: "1"
  },
  UniPiAnalogInput: {
    title: "UniPi Analog Input"
    description: "UniPi Analog Input"
    type: "object"
    extensions: ["xLink"]
    properties:
      circuit:
        description: "The Analog Input circuit id"
        type: "string"
        default: "1"
  },
  UniPiDigitalInput: {
    title: "UniPi Digital Input"
    description: "UniPi Digital Input"
    type: "object"
    extensions: ["xLink", "xOpenedLabel", "xClosedLabel"]
    properties:
      circuit:
        description: "The Digital Input circuit id"
        type: "string"
        default: "1"
  },
  UniPiTemperature: {
    title: "UniPi Temperature Sensor"
    description: "UniPi Temperature"
    type: "object"
    extensions: ["xLink"]
    properties:
      circuit:
        description: "The sensor circuit address"
        type: "string"
  }
}