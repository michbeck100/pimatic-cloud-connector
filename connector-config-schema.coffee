module.exports = {
  title: "Plugin config options"
  type: "object"
  properties:
    uuid:
      description: "Unique id for this pimatic instance"
      type: "string"
    secret:
      description: "Random secret for cloud authentication"
      type: "string"
    debug:
      description: "Enable debug output"
      type: "boolean"
      default: false
}
