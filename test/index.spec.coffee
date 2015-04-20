sinon           = require 'sinon'
should          = require 'should'
retry           = require 'retry'
redis           = require 'redis'
async           = require 'async'
{EventEmitter}  = require 'events'
{RedisPool}     = require "#{SRC}/index"
{redisCommands} = require "#{SRC}/commands"

describe 'Redis Pool', ->
  pool = null

  describe 'createClient', ->
    clock = null
    redisClient1 = null
    redisClient2 = null
    redisClient3 = null
    redisClient4 = null

    beforeEach ->
      clock = sinon.useFakeTimers();
      pool = new RedisPool
        retry:
          retries: 2
          minTimeout: 10
          maxTimeout: 200
      sinon.stub pool.pool, 'destroy'
      redisClient1 = new EventEmitter()
      redisClient2 = new EventEmitter()
      redisClient3 = new EventEmitter()
      redisClient4 = new EventEmitter()
      sinon.stub redis, 'createClient'
      redis.createClient.onCall(0).returns redisClient1
      redis.createClient.onCall(1).returns redisClient2
      redis.createClient.onCall(2).returns redisClient3
      redis.createClient.onCall(3).returns redisClient4

    afterEach ->
      clock.restore()
      redis.createClient.restore()
      pool.pool.destroy.restore()

    doTimeout = (delay, fn) ->
      setTimeout fn, delay
      clock.tick delay

    it 'should create client sucessfully', (done) ->
      pool.createClient (err, client) ->
        should.not.exist err
        client.should.be.exactly redisClient1
        done()
      redisClient1.emit 'ready'

    it 'should retry 1 time and return the client sucessfully', (done) ->
      pool.createClient (err, client) ->
        should.not.exist err
        client.should.be.exactly redisClient3
        done()
      err1 = new Error('Error A')
      err2 = new Error('Error A')
      redisClient1.emit 'error', err1
      redisClient1.emit 'end'
      doTimeout 500, ->
        redisClient2.emit 'error', err2
        redisClient2.emit 'end'
        doTimeout 500, ->
          redisClient3.emit 'ready'

    it 'should retry 2 times and finally give up if there is still error', (done) ->
      pool.createClient (err, client) ->
        err.should.eql err1
        should.not.exist client
        done()
      err1 = new Error('Error A')
      err2 = new Error('Error A')
      err3 = new Error('Error B')
      redisClient1.emit 'error', err1
      redisClient1.emit 'end'
      doTimeout 500, ->
        redisClient2.emit 'error', err2
        redisClient2.emit 'end'
        doTimeout 500, ->
          redisClient3.emit 'error', err3
          redisClient3.emit 'end'

    it 'should create client that will be removed from the pool if connection ends', (done) ->
      pool.createClient (err, client) ->
        client.emit 'end'
        sinon.assert.calledOnce pool.pool.destroy
        sinon.assert.alwaysCalledWith pool.pool.destroy, client
        done()

      redisClient1.emit 'ready'

  describe 'destroyClient', ->
    beforeEach ->
      pool = new RedisPool()

    it 'should do nothing if client status is not ready', ->
      client =
        poolClientStatus: 'error'
        quit: sinon.stub()
      pool.destroyClient client
      sinon.assert.notCalled client.quit

    it 'should call quit command if client status is ready', ->
      client =
        poolClientStatus: 'ready'
        quit: sinon.stub()
      pool.destroyClient client
      sinon.assert.calledOnce client.quit

    it 'should not fail if quit command throw exception', ->
      client =
        poolClientStatus: 'ready'
        quit: sinon.stub()
      client.quit.throws()
      pool.destroyClient client
      sinon.assert.calledOnce client.quit

  describe 'validateClient', ->
    beforeEach ->
      pool = new RedisPool()

    it 'should return true if client status is ready', ->
      pool.validateClient(poolClientStatus: 'ready').should.be.true

    it 'should return false if client status is not ready', ->
      pool.validateClient(poolClientStatus: 'error').should.be.false

  describe 'drain', ->
    redisClient1 = null
    redisClient2 = null
    redisClient3 = null
    redisClient4 = null

    beforeEach ->
      pool = new RedisPool pool: max: 4
      redisClient1 = new EventEmitter()
      redisClient1.quit = sinon.stub()
      redisClient2 = new EventEmitter()
      redisClient2.quit = sinon.stub()
      redisClient3 = new EventEmitter()
      redisClient3.quit = sinon.stub()
      redisClient4 = new EventEmitter()
      redisClient4.quit = sinon.stub()
      sinon.stub redis, 'createClient'
      redis.createClient.onCall(0).returns redisClient1
      redis.createClient.onCall(1).returns redisClient2
      redis.createClient.onCall(2).returns redisClient3
      redis.createClient.onCall(3).returns redisClient4

    afterEach ->
      redis.createClient.restore()

    it 'should drain the pool', (done) ->
      acquire = (callback) ->
        pool.acquire (err, client) ->
          callback()
      async.parallel [acquire, acquire, acquire, acquire], ->
        pool.drain ->
          sinon.assert.calledOnce redisClient1.quit
          sinon.assert.calledOnce redisClient2.quit
          sinon.assert.calledOnce redisClient3.quit
          sinon.assert.calledOnce redisClient4.quit
          pool.status.should.eql 'drained'
          done()
        pool.release redisClient1
        pool.release redisClient2
        pool.release redisClient3
        pool.release redisClient4
      redisClient1.emit 'ready'
      redisClient2.emit 'ready'
      redisClient3.emit 'ready'
      redisClient4.emit 'ready'

  describe 'commands', ->
    redisClient = null
    arg1 = name: 'arg1'
    arg2 = name: 'arg2'
    arg3 = name: 'arg3'
    resp1 = name: 'resp1'
    resp2 = name: 'resp2'

    beforeEach ->
      pool = new RedisPool()
      redisClient = new EventEmitter()
      redisCommands.forEach (command) -> redisClient[command] = sinon.stub().yields null, resp1, resp2
      redisClient.send_command = sinon.stub().yields null, resp1, resp2
      sinon.stub(redis, 'createClient').returns redisClient

    afterEach ->
      redis.createClient.restore()

    it 'should execute redis command', (done) ->
      async.map redisCommands, (command, callback) ->
        pool.command[command] arg1, arg2, arg3, (err, r1, r2) ->
          should.not.exist err
          r1.should.be.exactly resp1
          r2.should.be.exactly resp2
          sinon.assert.alwaysCalledWith redisClient[command], arg1, arg2, arg3
          callback null, command
      , done
      redisClient.emit 'ready'

    it 'should execute extra redis command', (done) ->
      pool.sendCommand 'custom', arg1, arg2, arg3, (err, r1, r2) ->
        should.not.exist err
        r1.should.be.exactly resp1
        r2.should.be.exactly resp2
        sinon.assert.alwaysCalledWith redisClient.send_command, 'custom', arg1, arg2, arg3
        done()
      redisClient.emit 'ready'
