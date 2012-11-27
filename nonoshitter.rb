#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

$: << File.dirname(__FILE__)

require "./lib/twbot2/twbot2"
require "rexml/document"
require "sqlite3"
require "./lib/util/DB"

# nonoshitter
class Nonoshitter < TwBot
  def load_data

    #initialize
    result = []
    me = File.dirname(__FILE__)
    db = DB.new("#{me}/dat/db/nono.db")

    #get words
    wordCount = db.countAll("words")
    targetID = (Time.now.usec % wordCount) + 1
    resultSet = db.findById("words", targetID)
    word = resultSet[0][1]

    #decoration
    if resultSet[0][2] == "1" then
      result[0] = "#{word}！！"
    else
      case rand(12)
        when 0
        result[0] = "この#{word}が！"
        when 1
        result[0] = "お前は本当に#{word}だな"
        when 2
        result[0] = "#{word}の分際で！"
        when 3
        result[0] = "うるせえ#{word}！"
        when 4
        result[0] = "ホームラン級の#{word}だな"
        when 5
        result[0] = "天下一#{word}会に出場しろよ"
        when 6
        result[0] = "お前の#{word}っぷりが雑誌で特集されてたぞ"
        when 7
        result[0] = "次世代の#{word}界を担える器だな"
        when 8
        result[0] = "すれ違いざまに小学生が「#{word}が来たぞ！」って言ってたの聞こえてた？"
        when 9
        result[0] = "今年のノーベル#{word}賞はお前で決まりだな"
        when 10
        result[0] = "「お客様の中に#{word}様はいらっしゃいませんか？」と言われたらちゃんと挙手しろよ"
        when 11
        result[0] = "いいぞ！今の発言はかなり#{word}っぽさが出ていた。研鑽を怠るなよ！"
      end
    end

    #get follower at random
    rep = self::getUserToReply

    if rep != nil then
      result[0] = "@#{rep} #{result[0]}"
    else
      result = []
    end

    result
  end

  #get screen_name from follower at random
  def getUserToReply
    followers = self::get_followers
    followers[:result][rand(followers[:result].length)]
  end
end

self_path = File.dirname(__FILE__)
ARGV.each do |mode|
  Nonoshitter.new mode, "#{self_path}/config.yml", "#{self_path}/dat/log/result.log"
end
