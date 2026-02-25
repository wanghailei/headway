# Shared test configuration for Headway. Sets up Bundler, loads Headway
# (which activates Zeitwerk autoloading), and configures minitest.

require "bundler/setup"
require "minitest/autorun"
require "fileutils"
require "tmpdir"

$LOAD_PATH.unshift File.expand_path( "../lib", __dir__ )
require "headway"
