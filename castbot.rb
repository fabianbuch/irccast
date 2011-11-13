require 'net/yail/irc_bot'
require 'date'
require 'twitter'

class CastBot < IRCBot
  BOTNAME = 'IrcCast'
  BOTVERSION = 'v0.1.0'
  POLL_INTERVAL = 60

  def initialize(options = {})
    @master = options.delete(:master)
    @channels = options[:channels] || {}

    options[:username] = BOTNAME
    options[:realname] = BOTNAME
    options[:nicknames] = options[:nicknames] || ['irccast', 'castbot']

    Twitter.configure do |config|
      config.consumer_key = options.delete(:consumer_key)
      config.consumer_secret = options.delete(:consumer_secret)
      config.oauth_token = options.delete(:oauth_token)
      config.oauth_token_secret = options.delete(:oauth_token_secret)
    end

    @client = Twitter::Client.new

    # Set up IRCBot, our loving parent, and begin
    super(options)
    self.connect_socket
    self.start_listening

  end

  # Add hooks on startup (base class's start method calls add_custom_handlers)
  def add_custom_handlers
    # Set up hooks
    @irc.prepend_handler(:incoming_msg, self.method(:_in_msg))
    @irc.prepend_handler(:incoming_invite, self.method(:_in_invited))
    @irc.prepend_handler(:incoming_kick, self.method(:_in_kick))

    @irc.prepend_handler(:outgoing_join, self.method(:_out_join))

    @irc.prepend_handler(:incoming_welcome, self.method(:twitter_timeline))
  end

  private
  # Incoming message handler
  def _in_msg(fullactor, user, channel, text)
    # check if this is a /msg command, or normal channel talk
    if channel =~ /#{bot_name}/
      incoming_private_message(user, text)
    else
      incoming_channel_message(user, channel, text)
    end
  end

  # Gives the user very simplistic information.
  def incoming_private_message(user, text)
    case text
      when /\bhelp\b/i
        msg(user, 'CastBot at your service - I broadcast a twitter timeline.')
        msg(user, 'If you /INVITE me to a channel, I\'ll pop in and start broadcasting there too.')
        return
    end

    msg(user, "If you'd like to know what I do, enter \"HELP\"")
  end

  def incoming_channel_message(user, channel, text)
    if @master == user
      if (text == "#{bot_name}: QUIT")
        self.irc.quit("Ordered by my master")
        sleep 1
        exit
      end
    end

    case text
      when /^\s*#{bot_name}(:|)\s*uptime\s*$/i
        msg(channel, get_uptime_string)

      when /botcheck/i
        msg(channel, "#{BOTNAME} #{BOTVERSION}")

    end
  end

  def _in_invited(fullactor, actor, target)
    join target
  end

  # If bot is kicked, he must rejoin!
  def _in_kick(fullactor, actor, target, object, text)
    #if object == bot_name
    #  # Rejoin almost immediately
    #  join target
    #end

    return true
  end

  # We're trying to join a channel - use key if we have one
  def _out_join(target, pass)
    key = @channels[target]
    pass.replace(key) unless key.to_s.empty?
  end

  def twitter_timeline(text, args)
    Thread.new do
      loop do
        begin
          poll_twitter_timeline.each do |tweet|
            tweet_id = tweet.id.to_i
            
            # multiple line tweets in one line
            tweettext = tweet.text.split(/\s+/).each {|el| el.strip! }.join(" ")
            
            if tweet_id > @last_id
              @last_id = tweet_id
              @channels.each do |channel|
                msg(channel, "[@\00303#{tweet.user.screen_name}\003] #{tweet.text}")
              end
            end
          end
        rescue Exception => e
          $stderr.puts "Exception in thread: #{e.class}: #{e}"
          $stderr.puts e.backtrace.join( "\n\t" )
        end
        sleep POLL_INTERVAL
      end
    end
  end

  def poll_twitter_timeline
    tweets_to_broadcast = []
    
    report ["polling tweets"]
    
    opts = @last_id ? { :since_id => @last_id } : {}
    tl = @client.home_timeline(opts)
    
    # the first time just save the last tweet id without broadcasting it
    if tl.any?
      if @last_id.nil?
        @last_id = tl[0].id.to_i
      else
        tl.reverse_each do |tweet|
          tweets_to_broadcast << tweet
        end
      end
    end
    
    return tweets_to_broadcast
  rescue Exception => e
    $stderr.puts "Twitter exception: #{e.message}"
    return []
  end

end