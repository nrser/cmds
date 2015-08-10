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
  def self.capture template, *subs, &input_block
    Cmds.debug "Cmds::capture with",
      input_block: input_block
    new(template, options(subs, input_block)).call
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
    capture.ok?
  end

  def error?
    capture.error?
  end

  def assert
    capture.raise_error
  end

end # class Cmds
