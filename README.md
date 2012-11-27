# nonoshitter
nonoshitter tweets abusive words.

## features
- get words from database at random
- tweet for random followers
- easy execution

## requires
- Ruby 1.9.2 up
- bundler
- twitter account for nonoshitter (with OAuth token)

## installing
    git clone https://github.com/bbpink/nonoshitter.git
    cd nonoshitter
    bundle install
And modify the config file(/config.yml) to set your OAuth token.

## usage
You should check the paths at the shell script file(bin/nono.sh) before execution.  
Then execute it like following.  

    cd nonoshitter
    sh bin/nono.sh

You can use the cron for more convinience.

## copyright
nonoshitter consists of greate bot library [twbot2.rb](http://maraigue.hhiro.net/twbot/index.php?lang=en "twbot2.rb").  
And you can use nonoshitter under [new BSD License](http://opensource.org/licenses/BSD-3-Clause "new BSD License").  
&copy;2012- [bbpink](https://twitter.com/bbpink "bbpink")
