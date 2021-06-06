class << ENV
  # call-seq:
  #   ENV.clone(freeze: nil) -> ENV
  #
  # Returns self, since the environment table is a singleton resource.
  # If +freeze+ keyword is given and not +nil+ or +false+, raises ArgumentError.
  def clone(freeze: nil)
    warn("ENV.#{__method__} returns ENV itself", category: :deprecated, uplevel: 1)
    __builtin_cstmt! <<-'C'
        if (RTEST(rb_obj_freeze_opt(freeze))) env_freeze(self);
        return self;
    C
  end

  # call-seq:
  #   ENV.dup -> ENV
  #
  # Returns self, since the environment table is a singleton resource.
  def dup
    warn("ENV.#{__method__} returns ENV itself", category: :deprecated, uplevel: 1)
    self
  end
end
