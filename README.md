Cmds
=============================================================================

[![Gem Version](http://img.shields.io/gem/v/cmds.svg)][gem]

[gem]: https://rubygems.org/gems/cmds

`Cmds` tries to make it easier to read, write and remember using shell commands
in Ruby.

It treats generating shell the in a similar fashion to generating SQL or HTML.

> This doc is best read at
> 
> <http://www.rubydoc.info/gems/cmds/>
> 
> where the API doc links should work and you got a table and contents.

Status
-----------------------------------------------------------------------------

Ya know, before you get too excited...

It's kinda starting to work. I'll be using it for stuff and seeing how it goes,
but no promises until `1.0` of course.

License
-----------------------------------------------------------------------------

MIT

Real-World Examples
-----------------------------------------------------------------------------

Or, "what's it look like?"...

1.  Instead of
    
    ```ruby
    `psql \
      --username=#{ (db_config['username'] || ENV['USER']).shellescape } \
      #{ db_config['database'].shellescape } \
      < #{ filepath.shellescape }`
    ```
    
    write
    
    ```ruby
    Cmds 'psql %{opts} %{db} < dump',
      db: db_config['database'],
      dump: filepath,
      opts: {
        username: db_config['username'] || ENV['USER']
      }
    ```
    
    to run a command like
    
    ```bash
    psql --username=nrser that_db < ./some/file/path
    ```
    
    Cmds takes care of shell escaping for you.
    
    
2.  Instead of
    
    ```ruby
    `PGPASSWORD=#{ config[:password].shellescape } \
      pg_dump \
        --username=#{ config[:username].shellescape } \
        --host=#{ config[:host].shellescape } \
        --port=#{ config[:port].shellescape } \
        #{ config[:database].shellescape } \
      > #{ filepath.shellescape }`
    ```
    
    which can be really hard to pick out what's going on from a quick glance, write
    
    ```ruby
    Cmds.new(
      'pg_dump <%=opts %{database}',
      kwds: {
        opts: {
          username: config[:username],
          host: config[:host],
          port: config[:port],
        },
        database: config[:database],
      },
      env: {
        PGPASSWORD: config[:password],
      },
    ).stream! { |io| io.out = filename }
    ```
    
    I find it much easier to see what's going on their quickly.
    
    Broken down, with some additional comments and examples:
    
    ```ruby
    # We're going to instantiate a new {Cmds} object this time, because we're
    # not just providing values for the string template, we're specifying an
    # environment variable for the child process too.
    # 
    cmd = Cmds.new(
      # The string template to use.
      'pg_dump %{opts} %{database}',
      
      # Keywords used in template substitution
      kwds: {
        # Hashes will automatically be expanded to CLI options. By default,
        # we use `--name=VALUE` format for long ones and `-n VALUE` for short,
        # but it's configurable.
        opts: {
          username: config[:username],
          host: config[:host],
          port: config[:port],
        },
        # As mentioned above, everything is shell escaped automatically
        database: config[:database],
      },
      
      # Pass environment as it's own Hash. There are options for how it is
      # provided to the child process as well.
      env: {
        # Symbol keys are fine, we'll take care of that for you
        PGPASSWORD: config[:password],
      },
    )
    
    # Take a look!
    cmd.prepare
    # => "PGPASSWORD=shhh\\! pg_dump --host=localhost --port=5432 --username=nrser blah"
    
    # Now stream it. the `!` means raise if the exit code is not 0
    exit_code = cmd.stream! { |io|
      # We use the block to configure I/O. Here we send the standard output to
      # a file, which can be a String, Pathname or IO object
      io.out = filename
    }
    ```

Installation
-----------------------------------------------------------------------------

Add this line to your application's `Gemfile`:

    gem 'cmds'


And then execute:

    bundle install


Or install it globally with:

    gem install cmds

Features
------------------------------------------------------------------------------

1.  {file:docs/features/templating.md Templating}
    
    Cmds treats generating commands like generating code. Following a practice
    well-established generating for SQL and HTML code Cmds uses string
    _templates_ with variable substitution to construct commands.
    
    The template language is [Embedded Ruby][] (AKA eRuby, ERB). Cmds uses the
    [Erubis][] implementation, which offers easier customization and extension
    over the built-in `erb` gem.
    
    Cmds takes advantage of that customization in two major ways:
    
    1.  _Shell escaping_ all rendered values by default. Escaping values for the
        shell is similar to the escaping problem in SQL and HTML, and
        escape-by-default both facilitates clearer and more concise code and
        helps avoid an entire class of bugs and security issues.
        
    2.  Supporting a more compact `%{expr}` syntax that is equivalent to the
        standard ERB form `<%= expr %>`.
        
    See {file:docs/features/templating.md docs/features/templating.md} for 
    details.
    
2.  {file:docs/features/io.md I/O}
    
    Cmds makes it easy to get data in and out of invoked commands, including via
    streaming.
    
    See {file:docs/features/io.md docs/features/io.md} for details.


-----------------------------------------------------------------------------
Old docs I haven't cleaned up yet...
-----------------------------------------------------------------------------

### execution

you can provide three types of arguments when executing a command:

1. positional arguments for substitution
2. keyword arguments for substitution
3. input to stdin

all `Cmds` instance execution methods have the same form for accepting these:

1. positional arguments are provided in an optional array that must be the first argument:
    
    `Cmds "cp <%= arg %> <%= arg %>", [src_path, dest_path]`
    
    note that the arguments need to be enclosed in square braces. Cmds does
    **NOT** use \*splat for positional arguments because it would make a `Hash`
    final parameter ambiguous.
    
2. keyword arguments are provided as optional hash that must be the last argument:
    
    `Cmds "cp <%= src %> <%= dest %>", src: src_path, dest: dest_path`
    
    in this case, curly braces are not required since Ruby turns the trailing keywords into a `Hash` provided as the last argument (or second-to-last argument in the case of a block included in the method signature).
    
3. input and output is handled with blocks:
    
    `Cmds(“wc -l”){ “one\ntwo\nthree\n” }
    
    Cmds.stream './test/tick.rb <%= times %>', times: times do |io|
      io.on_out do |line|
        # do something with the output line
      end
    
      io.on_err do |line|
        # do something with the error line
      end
    end`


### Reuse Commands

```
playbook = Cmds.new "ansible-playbook -i %{inventory} %{playbook}"
playbook.call inventory: "./hosts", playbook: "blah.yml"
```

currying

```
dev_playbook = playbook.curry inventory: "inventory/dev"
prod_playbook = playbook.curry inventory: "inventory/prod"

# run setup.yml on the development hosts
dev_playbook.call playbook: "setup.yml"

# run setup.yml on the production hosts
prod_playbook.call playbook: "setup.yml"
```


### defaults

NEEDS TEST

can be accomplished with reuse and currying stuff

```
playbook = Cmds.new "ansible-playbook -i %{inventory} %{playbook}", inventory: "inventory/dev"

# run setup.yml on the development hosts
playbook.call playbook: "setup.yml"

# run setup.yml on the production hosts
prod_playbook.call playbook: "setup.yml", inventory: "inventory/prod"
```


### input

```
c = Cmds.new("wc", input: "blah blah blah).call
```


### future..?

#### exec

want to be able to use to exec commands

#### formatters

kinda like `sprintf` formatters or string escape helpers in Rails, they would be exposed as functions in ERB and as format characters in the shorthand versions:

```
Cmds "blah <%= j obj %>", obj: {x: 1}
# => blah \{\"x\":1\}

Cmds "blah %j", [{x: 1}]
# => blah \{\"x\":1\}

Cmds "blah %<obj>j", obj: {x: 1}
# => blah \{\"x\":1\}
```

the `s` formatter would just format as an escaped string (no different from `<%= %>`).

other formatters could include

* `j` for JSON (as shown above)
* `r` for raw (unescaped)
* `l` or `,` for comma-separated list (which some commands like as input)
* `y` for YAML
* `p` for path, joining with `File.join`
