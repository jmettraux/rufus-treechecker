
= 'rufus-treechecker'

== what is it ?

Initialize a Rufus::TreeChecker and pass some ruby code to make sure it's safe before calling eval().


== features

.

== getting it

    sudo gem install -y rufus-treechecker

or download[http://rubyforge.org/frs/?group_id=4812] it from RubyForge.


== usage

    require 'rubygems'
    require 'rufus-treechecker'

    tc = Rufus::TreeChecker.new do
      exclude_method :abort
      exclude_methods :exit, :exit!
    end
    
    tc.check("1 + 1; abort")               # will raise a SecurityError
    tc.check("puts (1..10).to_a.inspect")  # OK

see more at ...


== dependencies

the 'rogue-parser' gem


== mailing list

On the Rufus-Ruby list[http://groups.google.com/group/rufus-ruby] :

    http://groups.google.com/group/rufus-ruby


== issue tracker

    http://rubyforge.org/tracker/?atid=18584&group_id=4812&func=browse


== source

http://github.com/jmettraux/rufus-treechecker

    git clone git://github.com/jmettraux/rufus-treechecker.git


== author

John Mettraux, jmettraux@gmail.com,
http://jmettraux.wordpress.com


== the rest of Rufus

http://rufus.rubyforge.org


== license

MIT

