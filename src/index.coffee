_               = require 'lodash'
redis           = require 'redis'
retry           = require 'retry'
{Pool}          = require 'generic-pool'
{redisCommands} = require './commands'

class RedisPool
  constructor: (options = {}) ->
    @clientNumber = 0
    @log = options.log
    @monitorInterval = options.monitorInterval
    @redisOptions = options.redis
    @retryOptions = options.retry
    @pool = new Pool _.extend {name: 'Redis Pool', log: false}, options.pool,
      create: @createClient.bind @
      destroy: @destroyClient.bind @
      validate: @validateClient.bind @
    @command = {}
    redisCommands.forEach (fnName) => @command[fnName] = @pool.pooled (client, args...) -> client[fnName].apply client, args
    @sendCommand =  @pool.pooled (client, args...) -> client.send_command.apply client, args
    @monitor()

  acquire: -> @pool.acquire.apply @pool, arguments

  release: -> @pool.release.apply @pool, arguments

  #Drain the pool gracefully
  drain: (callback) ->
    @pool.drain =>
      @pool.destroyAllNow()
      @status = 'drained'
      callback() if callback?

  logInfo: -> @log.info.apply @log, arguments if @log?

  logError: -> @log.error.apply @log, arguments if @log?

  createClient: (callback) ->
    poolClientNumber = @clientNumber++
    retryOperation = retry.operation @retryOptions
    retryOperation.attempt =>
      @logInfo "Redis Pool: Trying to establish client ##{poolClientNumber}, attempt #{retryOperation.attempts()}"
      #Force max_attempts = 1 to disable restry, we don't want to use the built in retry mechanism
      if @redisOptions?.unixSocket?
        client = redis.createClient @redisOptions.unixSocket, _.extend {}, @redisOptions, {max_attempts: 1}
      else
        client = redis.createClient @redisOptions?.port ? 6379, @redisOptions?.host ? '127.0.0.1', _.extend {}, @redisOptions, {max_attempts: 1}
      client.poolClientNumber = poolClientNumber
      client.poolClientStatus = 'new'
      client.on 'ready', @onClientReady.bind @, client, retryOperation, callback
      client.on 'end', @onClientEnd.bind @, client
      client.on 'error', @onClientError.bind @, client, retryOperation, callback

  onClientReady: (client, retryOperation, callback) ->
    @logInfo {redisServerInfo: client.server_info}, "Redis Pool: Client ##{client.poolClientNumber} established after #{retryOperation.attempts()} attempts and added to the pool"
    client.poolClientStatus = 'ready'
    callback null, client

  onClientEnd: (client) ->
    #Remove the client from the pool if the connection terminated unexpectedly
    if client.poolClientStatus is 'ready'
      @logError "Redis Pool: Client ##{client.poolClientNumber} ended unexpectedly"
      client.poolClientStatus = 'ended'
      @pool.destroy client

  onClientError: (client, retryOperation, callback, err) ->
    @logError err, "Redis Pool: Client ##{client.poolClientNumber} error"
    oldStatus = client.poolClientStatus
    client.poolClientStatus = 'error'
    #If the status is new, retry
    if oldStatus is 'new' and not retryOperation.retry err
        @logError "Redis Pool: Could not create client ##{client.poolClientNumber} after #{retryOperation.attempts()} attempts"
        callback retryOperation.mainError()

  destroyClient: (client) ->
    @logInfo "Redis Pool: Client ##{client.poolClientNumber} removed from the pool"
    #Try to quit politely if the status is ready
    if client.poolClientStatus is 'ready'
      try
        client.quit()
      catch err
        @logError err, "Redis Pool: Client ##{client.poolClientNumber} error"

  validateClient: (client) -> client.poolClientStatus is 'ready'

  monitor: ->
    # Report pool statistics
    if @monitorInterval? and @status isnt 'drained'
      @logInfo
        redisPoolInfo:
          size: "#{@pool.getPoolSize()}/#{@pool.getMaxPoolSize()}"
          available: @pool.availableObjectsCount()
          waiting: @pool.waitingClientsCount()
      , 'Redis Pool: Status'
      timeout = setTimeout @monitor.bind(@), @monitorInterval
      timeout.unref()

exports.RedisPool = RedisPool
