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


options = {}

opt['yaml'] ||= File.dirname(__FILE__) + '/config.yaml'
if File.exists?(opt['yaml'])
  options = File.open(opt['yaml']) {|f| YAML::load(f)}
  if File.exists?(File.dirname(__FILE__) + '/twitter.yaml')
    options.merge! File.open(File.dirname(__FILE__) + '/twitter.yaml') {|f| YAML::load(f)}
  end
end

for key in %w{network master passwords}
  options[key] ||= opt[key]
end

@bot = CastBot.new(
  :irc_network  => options['network'],
  :master       => options['master'],
  :passwords    => options['passwords'],
  :consumer_key => options["consumer_key"],
  :consumer_secret => options["consumer_secret"],
  :oauth_token => options["oauth_token"],
  :oauth_token_secret => options["oauth_token_secret"]
)
@bot.irc_loop
