module.exports = (env) =>
  util = require('util')
  fs = require('fs')
  http = require('http')
  path = require('path')
  uuid = require('uuid/v4')
  io = require('socket.io-client')

  class CloudConnectorPlugin extends env.plugins.Plugin

    cloudUrl = 'http://localhost:3000'

    dimmerTemplates: [
      'dimmer'
    ]

    switchTemplates: [
      'switch'
    ]

    heatingTemplates: [
      'thermostat'
    ]

    devices: {}

    connected = false

    init: (@app, @framework, @config) =>
      env.logger.info("Starting cloud connector...")

      if !@config.uuid
        uuid = uuid()
        @config.uuid = uuid
        env.logger.info("Generated uuid #{uuid}")

      if !@config.secret
        secret = @_randomString()
        @config.secret = secret
        env.logger.info("Generated secret #{secret}")

      @framework.on 'deviceAdded', (device) =>
        addDevice = (name, device) ->
          env.logger.debug("add device #{name}")
          @devices[name] = {
            device: device
          }
        if @_isActive(device)
          if @_isSupported(device)
            addDevice(@_getDeviceName(device), device)
            for additionalName in @_getAdditionalNames(device)
              addDevice(additionalName, device)
          else
            env.logger.warn("device #{device.name} not added, because #{device.template} is currently not supported. ")

      @framework.once "after init", =>
        if Object.keys(@devices).length == 0
          env.logger.info("No active devices found. Please make sure to activate your devices using pimatic-echo")
        socket = @_connect(@config.uuid, @config.secret)

        @framework.on 'destroy', (context) =>
          unless !@connected
            socket.emit('disconnect')


    _isActive: (device) =>
      return !!device.config.echo?.active

    _getDeviceName: (device) =>
      return if !!device.config.echo?.name then device.config.echo.name else device.name

    _getAdditionalNames: (device) =>
      if device.config.echo?.additionalNames?
        return device.config.echo.additionalNames
      else
        return []

    _isSupported: (device) =>
      return @_isDimmer(device) || @_isSwitch(device) || @_isHeating(device)

    _isDimmer: (device) =>

      return device.template in @dimmerTemplates

    _isSwitch: (device) =>
      return device.template in @switchTemplates

    _isHeating: (device) =>
      return device.template in @heatingTemplates

    _connect: (uuid, secret) =>
      socket = io(cloudUrl, {
        extraHeaders: {
          uuid: uuid,
          secret: secret,
          pimaticVersion: @framework.packageJson.version,
          clientVersion: require('./package').version
        }
      })
      socket.on('connect', () =>
        @connected = true
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
        env.logger.info("request: #{JSON.stringify(data)}")
        if data.path.indexOf('/api/') == 0
          env.logger.debug("calling #{data.path}")
          options = {
            port: @framework.config.settings.httpServer.port,
            path: data.path,
            auth: "admin:admin"
          }
          http.get(options, (res) =>
            res.setEncoding('utf8')
            rawData = ''
            res.on('data', (chunk) =>
              rawData += chunk
            )
            res.on('end', () =>
              parsedData = JSON.parse(rawData)
              socket.emit('responseContentBinary', {
                id: data.id,
                body: new Buffer(JSON.stringify(parsedData))
              })
              socket.emit('responseFinished', {
                id: data.id
              })
              env.logger.debug("response from pimatic: #{JSON.stringify(parsedData)}")
            )
          )
      )
      socket.on('cancel', (data) =>
        env.logger.info("cancel: #{data}")
      )
      socket.on('command', (data) =>
        env.logger.info("command: #{data}")
      )

      return socket

    _randomString: () =>
      length = 20
      return Math.round((Math.pow(36, length + 1) - Math.random() * Math.pow(36, length))).toString(36).slice(1)

  return new CloudConnectorPlugin()
