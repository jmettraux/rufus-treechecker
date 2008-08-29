#
#--
# Copyright (c) 2008, John Mettraux, jmettraux@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#++
#

#
# "made in Japan" (as opposed to "swiss made")
#

require 'ruby_parser' # gem 'rogue_parser'


module Rufus

  #
  # Instances of this error class are thrown when the ruby code being
  # checked contains exclude stuff
  #
  class SecurityError < RuntimeError
  end

  #
  # TreeChecker relies on ruby_parser to turns a piece of ruby code (a string)
  # into a bunch of sexpression and then TreeChecker will check that
  # sexpression tree and raise a Rufus::SecurityException if an excluded
  # pattern is spotted.
  #
  # The TreeChecker is meant to be useful for people writing DSLs directly
  # in Ruby (not via their own parser) that want to check and prevent
  # bad things from happening in this code.
  #
  #   tc = Rufus::TreeChecker.new do
  #     exclude_method :abort
  #     exclude_methods :exit, :exit!
  #   end
  #
  #   tc.check("1 + 1; abort")               # will raise a SecurityError
  #   tc.check("puts (1..10).to_a.inspect")  # OK
  #
  # == featured exclusion methods
  #
  # - exclude_method
  # - exclude_methods
  # - exclude_symbol
  #
  # - exclude_global_vars
  # - exclude_alias
  #
  class TreeChecker

    def initialize (&block)
      @checks = []
      instance_eval(&block)
    end

    def check (rubycode)

      do_check(parse(rubycode))
    end

    protected

    #
    # the methods used to define the checks

    def exclude_method (method_name)
      @checks << [ :do_exclude_method, method_name.to_sym ]
    end

    def exclude_methods (*method_names)
      method_names.each { |mn| exclude_method mn }
    end

    def exclude_symbol (symbol)
      @checks << [ :do_exclude_symbol, symbol.to_sym ]
    end

    #
    # bans referencing or setting the value of global variables
    #
    def exclude_global_vars
      @checks << [ :do_exclude_symbol, :gvar, "global vars are forbidden" ]
      @checks << [ :do_exclude_symbol, :gasgn, "global vars are forbidden" ]
    end

    #
    # bans the usage of 'alias'
    #
    def exclude_alias
      @checks << [ :do_exclude_symbol, :alias, "'alias' is forbidden" ]
    end

    #
    # the actual check method, check() is rather a bootstrap one...
    #
    def do_check (sexp)

      @checks.each do |exclusion_method, *args|
        send exclusion_method, sexp, args
      end

      return unless sexp.is_a?(Array) # check over, seems fine...

      # check children

      sexp.each { |c| do_check c }
    end

    #
    # the methods that actually perform the checks
    # (and potentially raise security exceptions)

    def do_exclude_method (sexp, args)

      return unless sexp.is_a?(Array) # lonely symbols are not method calls

      excluded_method_name = args.first
      head = sexp[0, 2]

      raise SecurityError.new(
        "call to method '#{excluded_method_name}' is forbidden"
      ) if (head == [ :vcall, excluded_method_name ] or
            head == [ :fcall, excluded_method_name ])
    end

    #
    # raises a Rufus::SecurityError if the sexp is a reference to
    # a certain symbol (like :gvar or :alias).
    #
    def do_exclude_symbol (sexp, args)

      raise SecurityError.new(
        args[1] || "symbol :#{excluded_symbol} is forbidden"
      ) if sexp == args[0]
    end

    #
    # a simple parse (relies on ruby_parser currently)
    #
    def parse (rubycode)

      RubyParser.new.parse(rubycode).to_a
    end
  end
end
