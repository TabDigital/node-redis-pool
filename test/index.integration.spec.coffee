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
    pool.command.set 'redisPoolTestKey', 'testValue', (err) ->
      should.not.exist err
      pool.command.get 'redisPoolTestKey', (err, result) ->
        should.not.exist err
        result.should.eql 'testValue'
        done()
