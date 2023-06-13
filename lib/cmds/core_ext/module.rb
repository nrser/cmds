# encoding: UTF-8

# Definitions
# =======================================================================

class Module
  
  # Like {Module#name} but also returns a {String} for anonymous classes.
  # 
  # So you don't need to do any testing or trying when you want to work
  # with the name of a module (or class, which are modules).
  # 
  # @return [String]
  # 
  def safe_name
    name = self.name
    return name if name.is_a? String
    
    # Slice out whatever that hex thingy that anon modules dump in their
    # `#to_s`... `"#<Class:0x00007fa6958c1700>" => "0x00007fa6958c1700"`
    # 
    # Might as well use that as an identifier so it matches their `#to_s`,
    # and this should still succeed in whatever funky way even if `#to_s`
    # returns something totally unexpected.
    # 
    to_s_hex = self.to_s.split( ':' ).last[0...-1]
    
    type_name = if self.is_a?( Class ) then "Class" else "Module" end
    
    "Anon#{ type_name }_#{ to_s_hex }"
  end # #safe_name
  
end
