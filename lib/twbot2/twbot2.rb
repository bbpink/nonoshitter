#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# ------------------------------------------------------------
# twbot2.rb - Twitter Bot Support Library in Ruby
# version 0.20
# 
# (C)2010- H.Hiro(Maraigue)
# * mail: main@hhiro.net
# * web: http://maraigue.hhiro.net/twbot/
# * Twitter: http://twitter.com/h_hiro_
# 
# This library is distributed under the (new) BSD license.
# See the bottom of this file.
# ------------------------------------------------------------

$: << File.dirname(__FILE__)+'/twbot2'

require 'devnull'
require 'rexml/document'
require 'yaml'
require 'rubygems'
require 'oauth'

class Exception
  def twbot_errorlog_format
    "#{self.class}: #{self}\n"+self.backtrace.map{ |x| "\t#{x}" }.join("\n")
  end
end

class TwBot
  # Consumer token of twbot2.rb
  # If you want to use this code for another application,
  # change the values of consumer key/secret to your application's ones.
  Consumer = OAuth::Consumer.new(
    "GcgsfkmFsT6THBOO9Qw", #consumer key
    "wgBJ8OPgQqyc8T8SArYkavvCDoIW2jh2K12jl4Qf8", #consumer secret
    :site => 'https://api.twitter.com')
  
  # ------------------------------------------------------------
  #   Instance methods
  # ------------------------------------------------------------
  
  # constructor
  def initialize(mode, config_file, log_file = nil, list = '', keep_config = false, test = false)
    if log_file.kind_of?(Hash)
      # If arguments are specified by a Hash
      list = log_file.fetch(:list, "")
      keep_config = log_file.fetch(:keep_config, false)
      test = log_file.fetch(:test, false)
      
      log_file = log_file.fetch(:log_file, nil)
    end
    
    # stores values in instance variables
    @mode = mode
    
    File.open(config_file, 'a'){ |f| } if @mode == "init"
    @config = YAML.load_file(config_file)
    @config = {} unless @config.kind_of?(Hash)
    
    @log = (log_file ? open(log_file, "a") : DevNull.new)
    @list = "data/#{list}"
    @keep_config = keep_config
    @test = test
    
    @logmsg = ""
    
    # load new message from user-defined code
    case @mode
    when "load"
      # load new messages
      @config[@list] ||= []
      
      begin
        new_updates = load_data
        if new_updates.any?{ |m| TwBot.validate_message(m) == nil }
          raise MessageFormatError, "Invalid object as a message is contained"
        end
      rescue Exception => e
        @logmsg << "<Error in load_data()> "+e.twbot_errorlog_format+"\n"
        @keep_config = true
      else
        @config[@list].concat new_updates
      end
    when /\Apost(?:=(\d+)(?:,(\d+))?)?\z/
      # post messages from the list
      post_count = ($1 ? $1.to_i : 1)
      retries = ($2 ? $2.to_i : 0)
      
      post_data(post_count, retries)
    when /\Aadd(?:=([0-9A-Z_a-z]+))?\z/
      # adding a user
      add_user($1, false)
    when "init"
      if @config["login/"]
        # If default login user is already registered
        # (updating from twbot.rb 0.1*)
        puts <<-OUT
============================================================
Here I help you retrieve OAuth token of user "#{@config['login/']}".
Please prepare a browser to retrieve OAuth tokens.
============================================================
        OUT
        
        add_user(@config["login/"], true)
      else
        # Otherwise
        puts <<-OUT
============================================================
Here I help you register your bot account to the setting file.
Please prepare a browser to retrieve OAuth tokens.

Input the screen name of your bot account.
============================================================
        OUT
        
        add_user(nil, true)
      end
    else
      @logmsg << "<Invalid mode: #{@mode}>"
    end
    
    # output log
    @logmsg = "[#{Time.now} mode=#{@mode}]#{@logmsg}"
    STDERR.puts @logmsg
    @log.puts @logmsg
    @log.close
    
    # output config
    unless @keep_config
      new_yaml = YAML.dump(@config)
      open(config_file, "w"){ |f| f.print new_yaml }
    end
  end
  
  # load data
  def load_data
    raise NotImplementedError, "Please inherit the class TwBot and override TwBot#load_data."
  end
  
  # post_data (private)
  def post_data(post_count, retries)
    while post_count > 0
      begin
        break if update_from_list(:duplicated => @config['duplicated/']) == nil
      rescue Exception => e
        @logmsg << "<Error in updating> #{e}\n"+e.twbot_errorlog_format+"\n"
        retries -= 1
        
        break if retries < 0
        redo
      end
      
      post_count -= 1
    end
  end
  private :post_data
  
  # update
  def update_from_list(info = @config["login/"])
    # parse parameters
    case info
    when String
      # If the parameter is given by a string,
      # It is treated as the user name
      user = info
      list = @list
      duplicated = "ignore"
    when Hash
      user = info.fetch(:user, @config["login/"])
      list = info.fetch(:list, @list)
      duplicated = info.fetch(:duplicated, @config['duplicated/']).to_s
      duplicated = "ignore" if duplicated == ""
    else
      raise ArgumentError, "A String (user name) or Hash (parameters) is required as the argument (#{info.class} given)"
    end
    
    # post messages
    auth = auth_http(user)
    
    trial = 0
    while true
      trial += 1
      
      # prepare the message
      if @config[list].empty?
        error_message = "(error: No message remains)"
        STDERR.puts error_message
        @logmsg << error_message
        return nil
      end
      
      message = @config[list].first
      request = TwBot.validate_message(message)
      raise MessageFormatError if request == nil
      
      if request[:status].empty?
        # If empty string is specified
        @config[list].shift
        @logmsg << "(skipped: An empty string specified)"
        return false
      end
      
      # send request
      if @test
        result = "'<status></status>" # dummy xml
      else
        result = auth.post("/1/statuses/update.xml", request).body
      end
      
      # Check the result
      unless TwBot.xml_begin_with(result, "status")
        # if failed
        if result.index("<error>Status is a duplicate.</error>")
          # if duplicated
          error_message = "(error: The status \"#{request[:status]}\" is not posted because of duplication)"
          STDERR.puts error_message
          @logmsg << error_message
            
          case duplicated
          when "seek"
            tmp = @config[list].shift
            @config[list].push tmp
          when "discard"
            @config[list].shift
            trial -= 1
          when "cancel"
            return false
          when "ignore"
            @config[list].shift
            return false
          end
        else
          # if another reason
          raise RuntimeError, "Posting a tweet has failed - XML data is:\n#{result}"
        end
      else
        # if succeeded
        
        # renew lists
        @config[list].shift
        
        # outputing / writing log
        STDERR.puts "[Updated!#{@testmode ? '(test)' : ''}] #{request[:status]}"
        @logmsg << "(A tweet has posted)"
        return result
      end
      
      return false if trial >= @config[@list].size
    end
  end
  
  # add a user
  def add_user(username, reload)
    until username
      print "User name >"
      username = STDIN.gets.chomp
      redo unless username =~ /\A[0-9A-Z_a-z]+\z/
    end
    
    if user_registered?(username)
      puts "The user \"#{username}\" is already registered."
      return
    end
    
    auth = auth_http(:user => username, :reload => reload, :browser => true)
    if auth != nil
      @config["login/"] = username if @config["login/"] == nil
      puts "User \"#{username}\" is successfully registered."
    end
  end
  private :add_user
  
  # check the user is registered in the config file
  # returns true if and only if registered with OAuth token
  def user_registered?(user)
    user_key = "users/#{user}"
    @config[user_key] && @config[user_key]["token"] && @config[user_key]["secret"]
  end
  
  # returns access token
  def auth_http(info = @config["login/"])
    # parse parameters
    case info
    when String
      # If the parameter is given by a string,
      # It is treated as the user name
      user = info
      reload = false
      browser = false
    when Hash
      user = info.fetch(:user, @config["login/"])
      reload = info.fetch(:reload, false)
      browser = info.fetch(:browser, false)
    else
      raise ArgumentError, "A String (user name) or Hash (parameters) is required as the argument (#{info.class} given)"
    end
    
    # creates an instance of AccessToken
    user_key = "users/#{user}"
    @config[user_key] ||= {}
    
    if reload || !(user_registered?(user))
      # if token is not stored, or the library user choosed not to use stored token,
      # retrieves it with xAuth or browser
      if browser
        # with browser
        access_token = TwBot.access_token_via_browser(user)
      else
        # with xAuth
        # 
        # Note:
        # TwBot is not allowed to use xAuth for now.
        # "TwBot.access_token_via_xauth" will always return HTTP 401 error.
        # (2010-04-30)
        unless @config[user_key]["password"]
          if user == @config["login/"]
            @config[user_key]["password"] = @config["password/"]
          else
            raise IncompleteConfigError, "Password for user \"#{user}\" is not specified."
          end
        end
        
        access_token = TwBot.access_token_via_xauth(user, @config[user_key]["password"])
      end
      
      return nil if access_token == nil
      
      # Store the result to @config
      @config[user_key]["token"] = access_token.token
      @config[user_key]["secret"] = access_token.secret
      
      # return the access token
      access_token
    else
      # if token is stored, creates access token with it
      OAuth::AccessToken.new(Consumer, @config[user_key]["token"], @config[user_key]["secret"])
    end
  end
  
  # get followers
  def get_followers
    TwBot.followers_of(auth_http)
  end
  
  # get friends
  def get_friends
    TwBot.friends_of(auth_http)
  end
  
  # follow a user
  def follow(target_user, auth = auth_http())
    result = auth.post("/1/friendships/create.xml", :screen_name => target_user)
    
    unless TwBot.xml_begin_with(result.body, "user")
      raise RuntimeError, "Failed in following @#{target_user}: HTTP result is\n#{result.body}"
    end
  end
  
  # unfollow a user
  def unfollow(target_user, auth = auth_http())
    result = auth.post("/1/friendships/destroy.xml", :screen_name => target_user)
    
    unless TwBot.xml_begin_with(result.body, "user")
      raise RuntimeError, "Failed in unfollowing @#{target_user}: HTTP result is\n#{result.body}"
    end
  end
  
  # get following status
  def following_status(target_user, auth = auth_http())
    result = auth.get("/1/friendships/show.xml?target_screen_name=#{target_user}")
    
    xml = REXML::Document.new(result.body)
    {:following =>
      TwBot.parse_boolean(
        xml.elements.to_a("/relationship/source/following").first.text),
     :followed =>
      TwBot.parse_boolean(
        xml.elements.to_a("/relationship/source/followed_by").first.text)}
  end
  
  # ------------------------------------------------------------
  #   Class methods (Utilities)
  # ------------------------------------------------------------
  
  # Separates reply string ("@USERNAME") into "@ USERNAME"
  # to avoid unintended replies.
  # If a block is given, "@USERNAME" is separated if the result
  # of the block is true.
  def self.remove_reply(str)
    str.gsub(/(@|＠)([0-9A-Z_a-z]+)/) do |x|
      if block_given?
        yield($2) ? "#{$1} #{$2}" : x
      else
        "#{$1} #{$2}"
      end
    end
  end

  # Checks the XML begin with specified element.
  # (ex.) TwBot.xml_begin_with("<foo><bar></bar></foo>", "foo") returns true.
  #       TwBot.xml_begin_with("<foo><bar></bar></foo>", "bar") returns false.
  # xmlstr is the source of XML to be checked.
  # If xmlstr is not valid as an XML document, returns nil.
  def self.xml_begin_with(xmlstr, name)
    begin
      REXML::Document.new(xmlstr).elements.to_a("/#{name}").size > 0
    rescue REXML::ParseException
      nil
    end
  end
  
  # If the specified string is "true" or "false" (case insensitive),
  # returns that boolean value. Otherwise raises an exception.
  def self.parse_boolean(str)
    case str
    when /\Atrue\z/i
      true
    when /\Afalse\z/i
      false
    else
      raise ArgumentError, "Value is neither of 'true' nor 'false'"
    end
  end
  
  # Converts values from user-defined "load_post" method
  # into HTTP request.
  # Returns nil if the value is invalid.
  def self.validate_message(obj)
    case obj
    when String
      {:status => obj}
    when Array
      return nil if obj.size != 2
      {:status => obj[0], :in_reply_to_status_id => obj[1].to_s}
    when Hash
      obj
    else
      nil
    end
  end
  
  # Get OAuth token (via xAuth)
  def self.access_token_via_xauth(username, password)
    Consumer.get_access_token(nil, {}, {
      :x_auth_mode => "client_auth",
      :x_auth_username => username,
      :x_auth_password => password})
  end
  
  # Get OAuth token (via browser)
  def self.access_token_via_browser(username)
    # ref: http://d.hatena.ne.jp/shibason/20090802/1249204953
    
    request_token = Consumer.get_request_token
    
    puts <<-OUT
============================================================
To retrieve OAuth token of user "#{username}":
(1) Log in Twitter with a browser for user "#{username}".
(2) Access the URL below with same browser:
    #{request_token.authorize_url}
(3) Check the application name is "twbot2.rb" and
    click "Allow" link in the browser.
(4) Input the shown number (PIN number).
    To cancel, input nothing and press enter key.
============================================================
    OUT
    
    pin_number = nil
    begin
      print "PIN number > "
      pin_number = STDIN.gets.chomp
    end until pin_number && pin_number =~ /\A\d*\z/
    
    return nil if pin_number == ""
    
    request_token.get_access_token(:oauth_verifier => pin_number)
  end
  
  # Retrieves users where the API returns paginated user list.
  # (ex. http://api.twitter.com/1/statuses/friends)
  # 
  # Stops retriving if API calls has failed for retry_count times.
  # 
  # The result is returned by a Hash of following format:
  # {:result => ["user1", "user2", ...],
  #  :gained_result => ["user1", "user2", ...],
  #  :id => [id1, id2, ...],
  #  :gained_id => [id1, id2, ...],
  #  :error => [exception1, exception2, ...]}
  #
  # :result and :gained_result represent the screen names,
  # while :id and :gained_id represent the users' ID numbers.
  # 
  # If API calls has failed for retry_count times,
  # :result and :id are both nil,
  # while :gained_result and :gained_id are both partial result.
  def self.paginated_user_list(path, auth, retry_count)
    user_list = []
    id_list = []
    error_list = []
    cursor = "-1"
    
    while true
      begin
        STDERR.puts "Downloading #{path} (cursor ID: #{cursor})"
        
        # Download users
        xml_source = auth.get("#{path}?cursor=#{cursor}").body
        
        # Parse XML
        xml = REXML::Document.new(xml_source)
        user_list.concat(
          xml.elements.to_a("/users_list/users/user/screen_name").map{
            |user_info| user_info.text } )
        id_list.concat(
          xml.elements.to_a("/users_list/users/user/id").map{
            |user_info| user_info.text.to_i } )
        
        # Get the cursor to the next page
        tmp = xml.elements.to_a("/users_list/next_cursor")
        if tmp.empty?
          raise RuntimeError, "Pagination of #{path} has failed"
        end
        cursor = tmp.first.text
        break if cursor == "0"
      rescue Exception => e
        STDERR.puts e.twbot_errorlog_format
        
        error_list << e
        retry_count -= 1
        break if retry_count <= 0
      end
    end
    
    {:gained_result => user_list,
     :gained_id => id_list,
     :result => (retry_count <= 0 ? nil : user_list.dup),
     :id =>     (retry_count <= 0 ? nil : id_list.dup),
     :error => error_list}
  end
  
  def self.followers_of(auth, retry_count = 3)
    paginated_user_list("/1/statuses/followers.xml", auth, retry_count)
  end
  
  def self.friends_of(auth, retry_count = 3)
    paginated_user_list("/1/statuses/friends.xml", auth, retry_count)
  end
  # ------------------------------------------------------------
  #   Exceptions
  # ------------------------------------------------------------
  
  # Raised when a lack of information is found in config file
  class IncompleteConfigError < RuntimeError
  end
  
  # Raised when the elements of array returned from load_data() is invalid
  class MessageFormatError < RuntimeError
  end
end

# Copyright (c) 2010-, Maraigue
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
# Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# Neither the name of the Maraigue nor the names of its contributors
# may be used to endorse or promote products derived from this
# software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
