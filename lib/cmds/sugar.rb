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


  # @api sugar
  #
  # captures and returns stdout
  # (sugar for `Cmds.capture(*template, *subs, &input_block).out`).
  #
  # @see .capture
  # @see Result#out
  #
  # @param template [String] see {.capture}.
  # @param subs [Array] see {.capture}.
  # @param input_block [Proc] see {.capture}.
  #
  # @return [String] the command's stdout.
  #
  def self.out template, *subs, &input_block
    capture(template, *subs, &input_block).out
  end


  # @api sugar
  #
  # captures and returns stdout, raising an error if the command fails.
  #
  # @see .capture
  # @see Result#out
  #
  # @param template [String] see {.capture}.
  # @param subs [Array] see {.capture}.
  # @param input_block [Proc] see {.capture}.
  #
  # @return [String] the command's stdout.
  #
  # @raise [SystemCallError] if the command fails (non-zero exit status).
  #
  def self.out! template, *subs, &input_block
    Cmds.new(
      template,
      options(subs, input_block).merge!(assert: true),
    ).capture.out
  end


  # @api sugar
  #
  # captures and chomps stdout
  # (sugar for `Cmds.out(*template, *subs, &input_block).chomp`).
  #
  # @see .out
  #
  # @param template [String] see {.capture}.
  # @param subs [Array] see {.capture}.
  # @param input_block [Proc] see {.capture}.
  #
  # @return [String] the command's chomped stdout.
  #
  def self.chomp template, *subs, &input_block
    out(template, *subs, &input_block).chomp
  end


  # @api sugar
  #
  # captures and chomps stdout, raising an error if the command fails.
  # (sugar for `Cmds.out!(*template, *subs, &input_block).chomp`).
  #
  # @see .out!
  #
  # @param template [String] see {.capture}.
  # @param subs [Array] see {.capture}.
  # @param input_block [Proc] see {.capture}.
  #
  # @return [String] the command's chomped stdout.
  #
  # @raise [SystemCallError] if the command fails (non-zero exit status).
  #
  def self.chomp! template, *subs, &input_block
    out!(template, *subs, &input_block).chomp
  end


  # @api sugar
  #
  # captures and returns stderr
  # (sugar for `Cmds.capture(template, *subs, &input_block).err`).
  #
  # @see .capture
  # @see Result#err
  #
  # @param template [String] see {.capture}.
  # @param subs [Array] see {.capture}.
  # @param input_block [Proc] see {.capture}.
  #
  # @return [String] the command's stderr.
  #
  def self.err template, *subs, &input_block
    capture(template, *subs, &input_block).err
  end

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


  # @api sugar
  #
  # captures and returns stdout
  # (sugar for `#capture(*subs, &input_block).out`).
  #
  # @see #capture
  # @see Result#out
  #
  # @param subs [Array] see {.capture}.
  # @param input_block [Proc] see {.capture}.
  #
  # @return [String] the command's stdout.
  #
  def out *subs, &input_block
    capture(*subs, &input_block).out
  end


  # @api sugar
  #
  # captures and returns stdout
  # (sugar for `#capture(*subs, &input_block).out`).
  #
  # @see #capture
  # @see Result#out
  #
  # @param subs [Array] see {.capture}.
  # @param input_block [Proc] see {.capture}.
  #
  # @return [String] the command's stdout.
  #
  # @raise [SystemCallError] if the command fails (non-zero exit status).
  #
  def out! *subs, &input_block
    self.class.new(
      @template,
      merge_options(subs, input_block).merge!(assert: true),
    ).capture.out
  end


  # @api sugar
  #
  # captures and chomps stdout
  # (sugar for `#out(*subs, &input_block).chomp`).
  #
  # @see #out
  #
  # @param subs [Array] see {.capture}.
  # @param input_block [Proc] see {.capture}.
  #
  # @return [String] the command's chomped stdout.
  #
  def chomp *subs, &input_block
    out(*subs, &input_block).chomp
  end


  # @api sugar
  #
  # captures and chomps stdout, raising an error if the command failed.
  # (sugar for `#out!(*subs, &input_block).chomp`).
  #
  # @see #capture
  # @see Result#out
  #
  # @param subs [Array] see {.capture}.
  # @param input_block [Proc] see {.capture}.
  #
  # @return [String] the command's chomped stdout.
  #
  # @raise [SystemCallError] if the command fails (non-zero exit status).
  #
  def chomp! *subs, &input_block
    out!(*subs, &input_block).chomp
  end


  # @api sugar
  #
  # captures and returns stdout
  # (sugar for `#capture(*subs, &input_block).err`).
  #
  # @param subs [Array] see {.capture}.
  # @param input_block [Proc] see {.capture}.
  #
  # @see #capture
  # @see Result#err
  #
  # @return [String] the command's stderr.
  #
  def err *subs, &input_block
    capture(*subs, &input_block).err
  end

end # class Cmds
