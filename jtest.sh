#!/bin/sh

LIBS=lib:test:\
/Library/Ruby/Gems/1.8/gems/rogue_parser-1.0.1/lib:\
/Library/Ruby/Gems/1.8/gems/ParseTree-2.1.1/lib
#LIBS=lib:test:\
#jlib/rogue:\
#jlib/parsetree

#~/jruby-1.1/bin/jruby -I$LIBS $1
#~/jruby-1.1/bin/jruby -X+C -I$LIBS $1
~/jruby-1.1.4/bin/jruby -I$LIBS $1
#~/jruby-1.1.4/bin/jruby -I$LIBS -X+C $1

