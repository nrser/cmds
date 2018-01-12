# Requirements
# =======================================================================

# Stdlib
# -----------------------------------------------------------------------
require 'pathname'

# Deps
# -----------------------------------------------------------------------
require 'nrser'

# Project / Package
# -----------------------------------------------------------------------
require 'cmds/version'
require 'cmds/debug'
require 'cmds/util'
require 'cmds/spawn'
require 'cmds/erb_context'
require 'cmds/shell_eruby'
require 'cmds/result'
require 'cmds/sugar'
require 'cmds/stream'
require 'cmds/capture'


# Definitions
# =======================================================================

class Cmds
  
  # Constants
  # ============================================================================
  
  # Absolute, expanded path to the gem's root directory.
  # 
  # @return [Pathname]
  # 
  ROOT = ( Pathname.new(__FILE__).dirname / '..' ).expand_path
  
  
  # Attributes
  # ============================================================================
  
  # ERB stirng template (with Cmds-specific extensions) for the command.
  # 
  # @return [String]
  # 
  attr_reader :template
  
  
  # base/common positional parameters to render into the command
  # template.
  # 
  # defaults to `[]`.
  # 
  # {#prepare} and the methods that invoke it (like {#capture},
  # {#stream}, etc.) accept `*args`, which will be appended to
  # these values to create the final array for rendering.
  # 
  # @return [Array<Object>]
  # 
  attr_reader :args
  
  
  # base/common keyword parameters to render into the command template.
  # 
  # defaults to `{}`.
  # 
  # {#prepare} and the methods that invoke it (like {#capture},
  # {#stream}, etc.) accept `**kwds`, which will be merged on top of
  # these values to create the final hash for rendering.
  # 
  # @return [Hash{Symbol => Object}]
  # 
  attr_reader :kwds
  

  # string or readable IO-like object to use as default input to the
  # command.
  # 
  # {#prepare} and the methods that invoke it (like {#capture},
  # {#stream}, etc.) accept an optional block that will override this
  # value if present.
  # 
  # @return [String | #read]
  # 
  attr_reader :input

  
  # if `true`, will execution will raise an error on non-zero exit code.
  # 
  # defaults to `false`.
  # 
  # @return [Boolean]
  # 
  attr_reader :assert

  
  # Environment variables to set for command execution.
  # 
  # defaults to `{}`.
  # 
  # @return [Hash{String | Symbol => String}]
  # 
  attr_reader :env
  
  
  # How environment variables will be set for command execution - inline at
  # the top of the command, or passed to `Process.spawn` as an argument.
  # 
  # See the `inline`
  # 
  # @return [:inline, :spawn_arg]
  # 
  attr_reader :env_mode
  

  # format specifier symbol:
  # 
  # -   `:squish`
  #     -   collapse rendered command string to one line.
  # -   `:pretty`
  #     -   clean up and backslash suffix line endings.
  # 
  # defaults to `:squish`.
  # 
  # @return [:squish | :pretty]
  attr_reader :format


  # Optional directory to run the command in, set by the `:chdir` option
  # in {Cmds#initialize}.
  # 
  # @return [nil]
  #   If the command will not change directory to run (default behavior).
  # 
  # @return [String | Pathname]
  #   If the command will change directory to run.
  #     
  attr_reader :chdir
  
  
  # The results of the last time {Cmds#prepare} was called on the instance.
  # 
  # A little bit funky, I know, but it turns out to be quite useful.
  # 
  # @return [nil]
  #   If {Cmds#prepare} has never been called.
  # 
  # @return [String]
  #   If {Cmds#prepare} has been called.
  # 
  attr_reader :last_prepared_cmd
  
  
  # Constructor
  # ============================================================================
  
  # Construct a `Cmds` instance.
  # 
  # @param [String] template
  #   String template to use when creating the command string to send to the
  #   shell via {#prepare}.
  #   
  #   Allows ERB (positional and keyword), `%s` (positional) and `%{name}`
  #   (keyword) placeholders.
  #   
  #   Available as the {#template} attribute.
  # 
  # @param [Array<Object>] args:
  #   Positional arguments to interpolate into the template on {#prepare}.
  #   
  #   Available as the {#args} attribute.
  # 
  # @param [Boolean] assert:
  #   When `true`, execution will raise an error if the command doesn't exit
  #   successfully (if the command exits with any status other than `0`).
  #   
  #   Available as the {#assert} attribute.
  # 
  # @param [nil | String | Pathname] chdir:
  #   Optional directory to change into when executing.
  #   
  #   Available as the {#chdir} attribute.
  # 
  # @param [Hash{(String | Symbol) => String}] env:
  #   Hash of environment variables to set when executing the command.
  #   
  #   Available as the {#env} attribute.
  # 
  # @param [:inline, :spawn_arg] env_mode:
  #   Controls how the env vars are added to the command.
  #   
  #   -   `:inline` adds them to the top of the prepared string. This is nice
  #       if you want do print the command out and paste it into a terminal.
  #       This is the default.
  #   
  #   -   `:spawn_arg` passes them as an argument to `Process.spawn`. In this
  #       case they will not be included in the output of {#prepare}
  #       (or {#render}).
  #   
  #   Available as the {#env_mode} attribute.
  # 
  # @param [nil, :squish, :pretty, #call] format:
  #   Dictates how to format the rendered template string before passing
  #   off to the shell.
  #   
  #   This feature lets you write templates in a more relaxed
  #   manner without `\` line-endings all over the place.
  #   
  #   -   `nil` performs **no formatting at all*.
  #       
  #   -   `:squish` reduces any consecutive whitespace (including newlines) to
  #       a single space. This is the default.
  #   
  #   -   `:pretty` tries to keep the general formatting but make it acceptable
  #       to the shell by adding `\` at the end of lines. See
  #       {Cmds.pretty_format}.
  #       
  #   -   An object that responds to `#call` will be called with the command
  #       string as it's only argument for custom formatting.
  #   
  #   See {Cmds.format} for more details.
  #   
  #   Available as the {#format} attribute.
  # 
  # @param [nil | String | #read] input:
  #   Input to send to the command on execution. Can be a string or an
  #   `IO`-like object that responds to `#read`.
  #   
  #   Available as the {#input} attribute.
  # 
  # @param [Hash{Symbol => Object}] kwds:
  #   Keyword arguments to shell escape and interpolate into the template on
  #   {#prepare}.
  #   
  #   Available as the {#kwds} attribute.
  # 
  def initialize  template, **opts
    opts = defaults opts
    
    Cmds.debug "Cmd constructing...",
      template: template,
      opts: opts

    @template = template
    
    # Assign options to instance variables
    opts.each { |key, value|
      instance_variable_set "@#{ key }", value
    }
    
    # An internal cache of the last result of calling {#prepare}, or `nil` if
    # {#prepare} has never been called. Kinda funky but ends up being useful.
    @last_prepared_cmd = nil
  end # #initialize
  
  
  # Instance Methods
  # ============================================================================
  # 
  # That ended up here. There are many more topically organized in
  # `//lib/cmds/*.rb` files.
  # 

  # returns a new {Cmds} with the parameters and input merged in
  def curry *args, **kwds, &input_block
    self.class.new template, {
      args: (self.args + args),
      kwds: (self.kwds.merge kwds),
      input: (input_block ? input_block.call : self.input),
      assert: self.assert,
      env: self.env,
      format: self.format,
      chdir: self.chdir,
    }
  end


  # render parameters into `@template`.
  # 
  # @note the returned string is **not** formatted for shell execution.
  #       Cmds passes this string through {Cmds.format} before execution,
  #       which addresses newlines in the rendered string through "squishing"
  #       everything down to one line or adding `\` to line ends.
  # 
  # @param args (see #capture)
  # @param kwds (see #capture)
  # 
  # @return [String]
  #   the rendered command string.
  # 
  def render *args, **kwds
    # Create the context for ERB
    context = Cmds::ERBContext.new(
      (self.args + args),
      
      self.kwds.merge( kwds ),
      
      tokenize_options_opts: TOKENIZE_OPT_KEYS.
        each_with_object( {} ) { |key, hash|
          value = instance_variable_get "@#{ key}"
          hash[key] = value unless value.nil?
        }
    )
    
    erb = Cmds::ShellEruby.new Cmds.replace_shortcuts( self.template )
    
    rendered = NRSER.dedent erb.result(context.get_binding)
    
    if self.env_mode == :inline && !self.env.empty?
      rendered = self.env.sort_by {|name, value|
        name
      }.map {|name, value|
        "#{ name }=#{ Cmds.esc value }"
      }.join("\n\n") + "\n\n" + rendered
    end
    
    rendered
  end


  # prepare a shell-safe command string for execution.
  # 
  # @param args (see #capture)
  # @param kwds (see #capture)
  # 
  # @return [String]
  #   the prepared command string.
  # 
  def prepare *args, **kwds
    @last_prepared_cmd = Cmds.format render(*args, **kwds), self.format
  end # #prepare
  
  
  # @!group Execution Instance Methods
  # ----------------------------------------------------------------------------
  # 
  # Methods that run the command.
  # 

  # execute command and return `true` if it exited successfully.
  # 
  # @param *args (see #capture)
  # @param **kwds (see #capture)
  # @param &input_block (see #capture)
  # 
  # @return [Boolean]
  #   `true` if exit code was `0`.
  # 
  def ok? *args, **kwds, &io_block
    stream(*args, **kwds, &io_block) == 0
  end


  # execute command and return `true` if it failed.
  # 
  # @param *args (see #capture)
  # @param **kwds (see #capture)
  # @param &input_block (see #capture)
  # 
  # @return [Boolean]
  #   `true` if exit code was not `0`.
  # 
  def error? *args, **kwds, &io_block
    stream(*args, **kwds, &io_block) != 0
  end


  def proxy
    stream do |io|
      io.in = $stdin
    end
  end


  # captures and returns stdout
  # (sugar for `#capture(*args, **kwds, &input_block).out`).
  #
  # @see #capture
  # @see Result#out
  #
  # @param *args (see #capture)
  # @param **kwds (see #capture)
  # @param &input_block (see #capture)
  #
  # @return [String]
  #   the command's stdout.
  #
  def out *args, **kwds, &input_block
    capture(*args, **kwds, &input_block).out
  end


  # captures and returns stdout
  # (sugar for `#capture(*args, **kwds, &input_block).out`).
  #
  # @see #capture
  # @see Result#out
  #
  # @param args [Array] see {.capture}.
  # @param kwds [Proc] see {.capture}.
  #
  # @return [String] the command's stdout.
  #
  # @raise [SystemCallError] if the command fails (non-zero exit status).
  #
  def out! *args, **kwds, &input
    capture(*args, **kwds, &input).assert.out
  end


  # captures and chomps stdout
  # (sugar for `#out(*subs, &input_block).chomp`).
  #
  # @see #out
  #
  # @param *args (see #capture)
  # @param **kwds (see #capture)
  # @param &input_block (see #capture)
  #
  # @return [String]
  #   the command's chomped stdout.
  #
  def chomp *args, **kwds, &input_block
    out(*args, **kwds, &input_block).chomp
  end


  # captures and chomps stdout, raising an error if the command failed.
  # (sugar for `#out!(*subs, &input_block).chomp`).
  #
  # @see #capture
  # @see Result#out
  #
  # @param *args (see #capture)
  # @param **kwds (see #capture)
  # @param &input_block (see #capture)
  #
  # @return [String]
  #   the command's chomped stdout.
  #
  # @raise [SystemCallError]
  #   if the command fails (non-zero exit status).
  #
  def chomp! *args, **kwds, &input
    out!(*args, **kwds, &input).chomp
  end


  # captures and returns stdout
  # (sugar for `#capture(*subs, &input_block).err`).
  #
  # @param *args (see #capture)
  # @param **kwds (see #capture)
  # @param &input_block (see #capture)
  # 
  # @see #capture
  # @see Result#err
  #
  # @return [String]
  #   the command's stderr.
  #
  def err *args, **kwds, &input_block
    capture(*args, **kwds, &input_block).err
  end
  
  # @!endgroup Execution Instance Methods
  
end # Cmds
