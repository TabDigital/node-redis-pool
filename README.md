# Redis Pool

> Client side connection pool for Redis

[![NPM](http://img.shields.io/npm/v/node-redis-pool.svg)](https://npmjs.org/package/node-redis-pool)
[![License](http://img.shields.io/npm/l/node-redis-pool.svg)](https://github.com/TabDigital/node-redis-pool)

[![Build Status](http://img.shields.io/travis/TabDigital/node-redis-pool.svg?style=flat)](http://travis-ci.org/TabDigital/node-redis-pool)
[![Dependencies](http://img.shields.io/david/TabDigital/node-redis-pool.svg?style=flat)](https://david-dm.org/TabDigital/node-redis-pool)
[![Dev dependencies](http://img.shields.io/david/dev/TabDigital/node-redis-pool.svg?style=flat)](https://david-dm.org/TabDigital/node-redis-pool)
## Install
`npm install node-redis-pool`
## Create a Redis pool
```javascript
var RedisPool = require('node-redis-pool').RedisPool;
var pool = new RedisPool(
  pool: {},  //Pool options
  retry: {}, //Retry options
  redis: {}, //Redis options
  log: {}, // Log object
  monitorInterval: 100 //Pool monitor dump interval
);
```  
- Pool options: [generic-pool](https://github.com/coopernurse/node-pool) (all options except `create`, `destroy` and `validate` functions)
- Retry options: [retry](https://github.com/tim-kos/node-retry)
- Redis options: [redis](https://github.com/mranney/node_redis) (all options plus `unixSocket`, `host` and `port`)
 - `unixSocket`: UNIX socket to use to connect to server
 - `host`: Redis server host
 - `port`: Redis server port  
- `log`: a logger object. It should have two methods `info` and `error`. See [bunyan](https://github.com/trentm/node-bunyan)
- `monitorInterval`: If you have log enabled, This value would be the interval in milliseconds that the pool has its information logged
```json
"redisPoolInfo": {
  "size": "4/5",
  "available": 2,
  "waiting": 4
}
```

## Acquire [redis client](https://github.com/mranney/node_redis) from the pool
```javascript
pool.acquire(function (err, client){
  //Do things with client
  //...
  //Release client to the pool
  pool.release(client);
});
```
##Redis commands
Most redis commands can be executed with implicit `acquire` and `release`
```javascript
pool.command.get('mykey', function(err, resp) {

});
```
Or
```javascript
pool.sendCommand('get', 'mykey', function(err, resp) {

});
```
###Draining
The pool should be drained gracefully
```javascript
pool.drain(function() {
  console.log("All connections have been drained");
});
```
