require 'shellwords'
require 'erubis'
require 'nrser'

class ShellEruby < Erubis::EscapedEruby
  def escaped_expr(code)
    "Shellwords.escape((#{code.strip}).to_s)"
  end
end

class ERBContext
  def initialize(args, kwargs)
    @args = args
    @kwargs = kwargs
    @arg_index = 0
  end

  def method_missing sym, *args, &block
    if args.empty? && block.nil?
      if sym.to_s[-1] == '?'
        key = sym.to_s[0...-1].to_sym
        @kwargs[key]
      else
        @kwargs.fetch(sym)
      end
    else
      super
    end
  end

  def get_binding
    binding
  end

  def arg
    @args.fetch(@arg_index).tap { @arg_index += 1 }
  end
end

tpl = <<-BLOCK
  defaults write <%= domain %> <%= key %> -dict
  <% values.each do |key, value| %>
    <%= key %> <%= value %>
  <% end %>
BLOCK

ctx = ERBContext.new [], { domain: 'com.nrser.blah',
                           key: "don't do it",
                           values: { x: '<ex>', y: 'why' } }

s = Text.squish ShellEruby.new(tpl).result(ctx.get_binding)

puts s
