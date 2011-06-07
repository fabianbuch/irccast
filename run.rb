#!/usr/bin/env ruby

require 'rubygems'
require 'twitter_oauth'
require 'net/yail'
require 'getopt/long'
require 'castbot'

opt = Getopt::Long.getopts(
  ['--network',     '-n', Getopt::OPTIONAL],
  ['--master',      '-m', Getopt::OPTIONAL],
  ['--yaml',        '-y', Getopt::OPTIONAL]
)

opt['yaml'] ||= File.dirname(__FILE__) + '/config.yml'
if File.exists?(opt['yaml'])
  options = File.open(opt['yaml']) {|f| YAML::load(f)}
else
  options = {}
end

for key in %w{network master}
  options[key] ||= opt[key]
end

@bot = CastBot.new(options)
@bot.irc_loop
