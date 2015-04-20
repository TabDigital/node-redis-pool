var should     = require('should');
var blanket    = require('blanket');
var requireDir = require('require-dir');

global.SRC = __dirname + '/../lib'

// only instrument the code if running test coverage
if (process.env['BLANKET']) {
  blanket({});
  requireDir(SRC, {recurse: true, duplicates: true});
}
