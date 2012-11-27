#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# ------------------------------------------------------------
# devnull.rb - A part of twbot2.rb
# 
# (C)2010- H.Hiro(Maraigue)
# * mail: main@hhiro.net
# * web: http://maraigue.hhiro.net/twbot/
# * Twitter: h_hiro_
# 
# This library is distributed under the (new) BSD license.
# See the bottom of "../twbot2.rb".
# ------------------------------------------------------------

require "enumerator"

class DevNull
  def initialize
    # do nothing
  end
  
  # methods that do nothing
  def <<(obj); end
  def close; end
  def close_read; end
  def close_write; end
  def fileno; end
  def print(*args); end
  def printf(*args); end
  def putc(*args); end
  def puts(*args); end
  def seek(*args); end
  def syswrite(*args); end
  def ungetbyte(*args); end
  def ungetc(*args); end
  def write(*args); end
  
  # methods that do nothing and returns something
  def getc; nil; end
  def getbyte; nil; end
  def gets(*args); nil; end
  def path; nil; end
  def pid; nil; end
  
  def binmode; self; end
  def flush; self; end
  def reopen(*args); self; end
  def set_encoding(*args); self; end
  
  def eof; true; end
  def eof?; true; end
  def sync; true; end
  
  def closed_read?; false; end
  def closed_write?; false; end
  def isatty; false; end
  def tty?; false; end
  
  def fsync; 0; end
  def pos; 0; end
  def tell; 0; end
  def rewind; 0; end
  
  def readlines(*args); []; end
  
  def sync=(arg); arg; end
  def truncate(arg); arg; end
  
  def each(*args); (block_given? ? self : [].to_enum); end
  alias :each_line :each
  alias :each_byte :each
  def external_encoding; "US-ASCII"; end
  def internal_encoding; "US-ASCII"; end
  def fcntl; raise NotImplementedError; end
  def readchar; raise EOFError; end
  def readbyte; raise EOFError; end
  def readline(*args); raise EOFError; end
  
  def read(len = 0, outbuf = nil)
    outbuf.replace("") if outbuf != nil
    (len.to_i == 0 ? "" : nil)
  end
  alias :sysread :read
  alias :readpartial :read
end
