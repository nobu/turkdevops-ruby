module Process
  class Status

    # call-seq:
    #    stat == other   -> true or false
    #
    # Returns +true+ if the integer value of _stat_
    # equals <em>other</em>.
    def ==(other)
      __builtin_inline! %q{
        if (self == other) return Qtrue;
        return rb_equal(pst_to_i(self), other);
      }
    end
  end
end
