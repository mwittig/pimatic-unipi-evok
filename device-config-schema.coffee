module.exports = {
  title: "pimatic-probe device config schemas"
  UniPiRelay: {
    title: "UniPi Relay"
    description: "UniPi Relay"
    type: "object"
    extensions: ["xConfirm", "xLink", "xOnLabel", "xOffLabel"]
    properties:
      circuit:
        description: "The circuit id [1-8] of the Relay"
        type: "number"
  }
}