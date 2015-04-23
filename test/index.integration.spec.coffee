sinon           = require 'sinon'
should          = require 'should'
retry           = require 'retry'
redis           = require 'redis'
async           = require 'async'
{EventEmitter}  = require 'events'
{RedisPool}     = require "#{SRC}/index"
{redisCommands} = require "#{SRC}/commands"

describe 'Redis Pool @integration Test', ->
  it 'should connect to redis and execute command', (done) ->
    pool = new RedisPool()
    pool.client.set 'redisPoolTestKey', 'testValue', (err) ->
      should.not.exist err
      pool.client.get 'redisPoolTestKey', (err, result) ->
        should.not.exist err
        result.should.eql 'testValue'
        done()

  it 'should test redis connection', (done) ->
    pool = new RedisPool()
    pool.testConnection (err, serverInfo) ->
      should.not.exist err
      should.exist serverInfo
      serverInfo.redis_version.should.not.empty
      done()
