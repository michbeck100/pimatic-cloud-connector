module.exports = (env) =>
  fs = require('fs')
  path = require('path')
  uuid = require('uuid/v4')
  io = require('socket.io-client')

  class CloudConnectorPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      env.logger.info("Starting cloud connector...")
      @storagePath = path.resolve(@framework.maindir, '../../cloud')
      if !fs.existsSync(@storagePath)
        fs.mkdirSync(@storagePath)
      uuid = @getInstanceUUID()
      secret = @getSecret()

      @connect(uuid, secret)



    connect: (uuid, secret) =>
      socket = io('http://localhost:3000', {
        extraHeaders: {
          uuid: uuid,
          secret: secret,
          pimaticVersion: "2.0", #TODO
          clientVersion: "0.0.1", #TODO
        }
      })
      socket.on('connect', () =>
        env.logger.info('Successfully connected to pimatic cloud')
      )
      socket.on('event', (data) =>
        env.logger.info('event')
      )
      socket.on('disconnect', () =>
        env.logger.info('Disconnected from pimatic cloud')
      )
      socket.on('error', (error) =>
        env.logger.info("Error on socket connection: #{error}")
      )

      socket.on('request', (data) =>
        env.logger.info("request: #{data}")
      )
      socket.on('cancel', (data) =>
        env.logger.info("cancel: #{data}")
      )
      socket.on('command', (data) =>
        env.logger.info("command: #{data}")
      )

    getSecret: () =>
      secretfile = path.resolve(@storagePath, 'secret')
      return @readFromFile(secretfile, @randomString)

    getInstanceUUID: () =>
      uuidfile = path.resolve(@storagePath, 'uuid')
      return @readFromFile(uuidfile, uuid)

    readFromFile: (file, creator) =>
      result = null
      if fs.existsSync(file)
        result = fs.readFileSync(file).toString()
      if !result
        result = creator()
        fs.appendFileSync(file, result)
        env.logger.info("created #{result}")
      else
        env.logger.debug("restored #{result} from existing file")
      return result


    randomString: () =>
      length = 20
      return Math.round((Math.pow(36, length + 1) - Math.random() * Math.pow(36, length))).toString(36).slice(1)


  return new CloudConnectorPlugin()
