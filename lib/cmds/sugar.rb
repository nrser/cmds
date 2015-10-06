# convenience methods

# global methods
# ==============

# proxies to `Cmds::capture`
def Cmds *args, &block
  Cmds.capture *args, &block
end

# proxies to `Cmds::ok?`
def Cmds? *args, &block
  Cmds.ok? *args, &block
end

# proxies to `Cmds::assert`
def Cmds! *args, &block
  Cmds.assert *args, &block
end

class Cmds
  # class methods
  # =============

  # create a new Cmd from template and subs and call it
  # @return [Result]
  def self.capture template, *subs, &input_block
    new(template, options(subs, input_block)).capture
  end

  def self.ok? template, *subs, &input_block
    new(template, options(subs, input_block)).ok?
  end

  def self.error? template, *subs, &input_block
    new(template, options(subs, input_block)).error?
  end

  def self.assert template, *subs, &input_block
    new(
      template,
      options(subs, input_block).merge!(assert: true)
    ).capture
  end

  def self.stream template, *subs, &input_block
    Cmds.new(template).stream *subs, &input_block
  end

  def self.stream! template, *subs, &input_block
    Cmds.new(template, assert: true).stream *subs, &input_block
  end # ::stream!

  # instance methods
  # ================

  alias_method :call, :capture

  def ok?
    stream == 0
  end

  def error?
    stream != 0
  end

  # def assert
  #   capture.raise_error
  # end

  def proxy
    stream do |io|
      io.in = $stdin
    end
  end

end # class Cmds
