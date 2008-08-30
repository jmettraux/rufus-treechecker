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
  #     exclude_fvcall :abort
  #     exclude_fvcall :exit, :exit!
  #   end
  #
  #   tc.check("1 + 1; abort")               # will raise a SecurityError
  #   tc.check("puts (1..10).to_a.inspect")  # OK
  #
  #
  # == featured exclusion methods
  #
  # === call / vcall / fcall ?
  #
  # What the difference between those ? Well, here is how those various piece
  # of code look like :
  #
  #   "exit"          => [:vcall, :exit]
  #   "Kernel.exit"   => [:call, [:const, :Kernel], :exit]
  #   "Kernel::exit"  => [:call, [:const, :Kernel], :exit]
  #   "k.exit"        => [:call, [:vcall, :k], :exit]
  #   "exit -1"       => [:fcall, :exit, [:array, [:lit, -1]]]
  #
  # Obviously :fcall could be labelled as "function call", :call is a call
  # on to some instance, while vcall might either be a variable dereference
  # or a function call with no arguments.
  #
  # === low-level rules
  #
  # - exclude_symbol
  # - exclude_fcall
  # - exclude_vcall
  # - exclude_fvcall
  # - exclude_fvkcall
  # - exclude_call_on
  # - exclude_call_to
  # - exclude_def
  # - exclude_class_tinkering
  # - exclude_module_tinkering
  # - is_not
  #
  # === higher level rules
  #
  # Those rules take no arguments
  #
  # - exclude_eval : bans eval, module_eval and instance_eval
  # - exclude_global_vars : bans calling or modifying global vars
  # - exclude_alias : bans calls to alias and alias_method
  # - exclude_vm_exiting : bans exit, abort, ...
  # - exclude_raise : bans calls to raise or throw
  #
  #
  # == a bit further
  #
  # It's possible to clone a TreeChecker and to add some more rules to it :
  #
  #   tc0 = Rufus::TreeChecker.new do
  #     #
  #     # calls to eval, module_eval and instance_eval are not allowed
  #     #
  #     exclude_eval
  #   end
  #
  #   tc1 = tc0.clone
  #   tc1.add_rules do
  #     #
  #     # calls to any method on File and FileUtils classes are not allowed
  #     #
  #     exclude_call_on File, FileUtils
  #   end
  #
  class TreeChecker

    VERSION = '1.0'

    #
    # initializes the TreeChecker, expects a block
    #
    def initialize (&block)

      @topchecks = []
      @checks = []

      add_rules(&block)
    end

    #
    # Performs the check on the given String of ruby code. Will raise a
    # Rufus::SecurityError if there is something excluded by the rules
    # specified at the initialization of the TreeChecker instance.
    #
    def check (rubycode)

      sexp = parse(rubycode)

      @topchecks.each do |meth, *args|
        send meth, sexp, args
      end

      do_check(sexp)
    end

    #
    # return a copy of this TreeChecker instance
    #
    def clone

      copy = TreeChecker.new
      copy.instance_variable_set(:@checks, @checks.dup)
      copy
    end

    #
    # adds a set of checks (rules) to this treechecker. Returns self.
    #
    def add_rules (&block)

      instance_eval(&block) if block

      self
    end

    #
    # generates a 'classic' tree checker
    #
    # Here is how it's built :
    #
    #    return TreeChecker.new do
    #      exclude_fvkcall :abort
    #      exclude_fvkcall :exit, :exit!
    #      exclude_fvkcall :system
    #      exclude_eval
    #      exclude_alias
    #      exclude_global_vars
    #      exclude_call_on File, FileUtils
    #      exclude_class_tinkering
    #      exclude_module_tinkering
    #    end
    #
    def self.new_classic_tree_checker

      return TreeChecker.new do
        exclude_fvkcall :abort
        exclude_fvkcall :exit, :exit!
        exclude_fvkcall :system
        exclude_eval
        exclude_alias
        exclude_global_vars
        exclude_call_on File, FileUtils
        exclude_class_tinkering
        exclude_module_tinkering
      end
    end

    protected

    #--
    # the methods used to define the checks
    #++

    #
    # setting an is_not rule only operates at the top level of a sexp
    # (hence it's stored in @topchecks)
    #
    def is_not (sym, message=nil)

      @topchecks << [ :do_is_not, sym.to_sym, message ]
    end

    [
      :exclude_symbol,
      :exclude_fcall,
      :exclude_vcall,
      :exclude_fvcall,
      :exclude_fvkcall,
      :exclude_call_on,
      :exclude_call_to

    ].each do |m|
      class_eval <<-EOS
        def #{m} (*args)

          message = args.last.is_a?(String) ? args.pop : nil

          args.each do |a| 

            a = [ Class, Module ].include?(a.class) ? \
              parse(a.to_s) : a.to_sym

            @checks << [ :do_#{m}, a, message ]
          end
        end
      EOS
    end

    #
    # bans method definitions
    #
    def exclude_def

      @checks << [
        :do_exclude_symbol, :defn, "method definitions are forbidden" ]
    end

    #
    # bans the defintion and the [re]openening of classes
    #
    # a list of exceptions (classes) can be passed. Subclassing those
    # exceptions is permitted.
    #
    def exclude_class_tinkering (*exceptions)

      @checks << [
        :do_exclude_class_tinkering ] + exceptions.collect { |e| parse(e.to_s) }
      @checks << [
        :do_exclude_symbol, :sclass, "defining or opening a class is forbidden"
      ]
    end

    #
    # bans the definition or the opening of modules
    #
    def exclude_module_tinkering

      @checks << [
        :do_exclude_symbol, :module, "defining or opening a module is forbidden"
      ]
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

      @checks << [
        :do_exclude_symbol, :alias, "'alias' is forbidden" ]
      @checks << [
        :do_exclude_symbol, :alias_method, "'alias_method' is forbidden" ]
    end

    #
    # bans the use of 'eval', 'module_eval' and 'instance_eval'
    #
    def exclude_eval

      @checks << [
        :do_exclude_fcall,
        :eval,
        "eval() is forbidden" ]
      @checks << [
        :do_exclude_call_to,
        :instance_eval,
        "instance_eval() is forbidden" ]
      @checks << [
        :do_exclude_call_to,
        :module_eval,
        "module_eval() is forbidden" ]
    end

    #
    # bans the use of backquotes
    #
    def exclude_backquotes
      @checks << [ :do_exclude_symbol, :xstr, "backquotes are forbidden" ]
    end

    #
    # bans raise and throw
    #
    def exclude_raise

      @checks << [ :do_exclude_fvkcall, :raise, "raise is forbidden" ]
      @checks << [ :do_exclude_fvkcall, :throw, "throw is forbidden" ]
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

    #
    # constructs a new set of arguments by inserting the newhead at the
    # beginning of the arguments
    #
    def cons (newhead, args)

      newhead = Array(newhead)
      newhead << args[0]

      [ newhead ] + (args[1, -1] || [])
    end

    def do_exclude_fcall (sexp, args)

      do_exclude_head(sexp, cons(:fcall, args))
    end

    def do_exclude_vcall (sexp, args)

      do_exclude_head(sexp, cons(:vcall, args))
    end

    #
    # excludes :fcall and :vcall
    #
    def do_exclude_fvcall (sexp, args)

      do_exclude_fcall(sexp, args)
      do_exclude_vcall(sexp, args)
    end

    #
    # excludes :fcall and :vcall and :call on Kernel
    #
    def do_exclude_fvkcall (sexp, args)

      do_exclude_fvcall(sexp, args)
      do_exclude_head(sexp, cons([ :call, [ :const, :Kernel ] ], args))
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
    # raises a security error if the sexp is a call on a given constant or
    # module (class)
    #
    def do_exclude_call_on (sexp, args)

      do_exclude_head(sexp, [ [:call, args[0]] ] + (args[1, -1] || []))
    end

    #
    # raises a security error if a call to a given method of any instance
    # is found
    #
    def do_exclude_call_to (sexp, args)

      return unless sexp.is_a?(Array)

      raise SecurityError.new(
        args[1] || "calls to '#{args[0]}' are forbidden"
      ) if sexp[0] == :call and sexp[2] == args[0]
    end

    def do_exclude_head (sexp, args)

      return unless sexp.is_a?(Array)

      head = args[0]

      raise SecurityError.new(
        args[1] || "#{head.inspect}' is forbidden"
      ) if sexp[0, head.length] == head
    end

    #
    # used in top level checks only
    # (used in ruote's check_conditional method to ensure that a piece
    # of code has 1! statement and is not a assignment)
    #
    def do_is_not (sexp, args)

      return unless sexp.is_a?(Array)

      raise SecurityError.new(
        args[1] || "the code may not begin with a :#{args[0]}"
      ) if sexp.first == args[0]
    end

    def do_exclude_class_tinkering (sexp, args)

      return unless sexp.is_a?(Array) # lonely symbols are not class definitions

      return unless sexp[0] == :class

      raise SecurityError.new(
        'class definition or opening forbidden'
      ) if args.length == 0 or ( ! args.include?(sexp[2]))
        #
        # raise error if there are no exceptions or
        # if the parent class is not a member of the exception list
    end

    #
    # a simple parse (relies on ruby_parser currently)
    #
    def parse (rubycode)

      #(@parser ||= RubyParser.new).parse(rubycode).to_a
        #
        # parser goes ballistic after a while, seems having a new parser
        # each is not heavy at all

      RubyParser.new.parse(rubycode).to_a
    end
  end
end
