# Shared test configuration for Headway. Sets up minitest and adds
# lib/ to the load path.

require "minitest/autorun"
require "fileutils"
require "tmpdir"

$LOAD_PATH.unshift File.expand_path( "../lib", __dir__ )
