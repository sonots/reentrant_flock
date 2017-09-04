$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "reentrant_flock"

require 'test/unit'
require 'test/unit/power_assert'

TEST_DIR = File.dirname(__FILE__)
TEST_TMP_DIR = File.join(TEST_DIR, 'tmp')
