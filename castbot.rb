require 'net/yail/irc_bot'
require 'date'

class CastBot < IRCBot
  BOTNAME = 'IrcCast'
  BOTVERSION = 'v0.1.0'

  def initialize(options = {})
    @master       = options.delete(:master)
    @output_dir   = options.delete(:output_dir) || File.dirname(__FILE__)

    # Log files per channel - logs rotate every so often, so we have to store
    # filenames on a per-channel basis
    @current_log  = {}
    @log_date     = {}
    @passwords    = options[:passwords] || {}

    options[:username] = BOTNAME
    options[:realname] = BOTNAME
    options[:nicknames] = ['SynyxCast', 'Cast_Bot']

    # Set up IRCBot, our loving parent, and begin
    super(options)
    self.connect_socket
    self.start_listening
  end

  # Add hooks on startup (base class's start method calls add_custom_handlers)
  def add_custom_handlers
    # Set up hooks
    @irc.prepend_handler(:incoming_msg,             self.method(:_in_msg))
    @irc.prepend_handler(:incoming_act,             self.method(:_in_act))
    @irc.prepend_handler(:incoming_invite,          self.method(:_in_invited))
    @irc.prepend_handler(:incoming_kick,            self.method(:_in_kick))

    @irc.prepend_handler(:outgoing_join,            self.method(:_out_join))
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
    key = @passwords[target]
    pass.replace(key) unless key.to_s.empty?
  end

end