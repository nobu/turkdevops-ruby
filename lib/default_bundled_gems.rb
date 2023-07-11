# frozen-string-literal: true

Gem.singleton_class.prepend Module.new {
  DEFAULT_BUNDLED_GEMS = Data.define(:exact, :prefix, :warned) do
    conf = RbConfig::CONFIG
    LIBDIR = conf["rubylibdir"] + "/"
    ARCHDIR = conf["rubyarchdir"] + "/"
    DLEXT = /\.#{Regexp.union([conf["DLEXT"], "so"].uniq)}\z/

    def find_gem(path)
      if !path
        return
      elsif path.start_with?(ARCHDIR)
        n = path.delete_prefix(ARCHDIR).sub(DLEXT, "")
      elsif path.start_with?(LIBDIR)
        n = path.delete_prefix(LIBDIR).chomp(".rb")
      else
        return
      end
      exact[n] or prefix[n[%r[\A[^/]+(?=/)]]]
    end

    def warning?(name)
      _t, path = $:.resolve_feature_path(name)
      return unless gem = find_gem(path)
      caller, = caller_locations(3, 1)
      return if find_gem(caller&.absolute_path)
      return if warned[name]
      warned[name] = true
      if gem == true
        "`#{name}' will be gemified; add to Gemfile"
      elsif gem
        return if warned[gem]
        warned[gem] = true
        "`#{name}' is found in `#{gem}' which will be gemified; add to Gemfile"
      end
    end

    def initialize(exact:, prefix:)
      super(exact: exact, prefix:, warned: {})
    end
  end.new(
    exact: {
      "abbrev"=>true,
      "base64"=>true,
      "csv"=>true,
      "drb"=>true,
      "getoptlong"=>true,
      "mutex_m"=>true,
      "nkf"=>true, "kconv"=>"nkf",
      "observer"=>true,
      "resolv-replace"=>true,
      "rinda"=>true,
      "syslog"=>true,
    }.freeze,
    prefix: {
      "csv" => true,
      "drb" => true,
      "rinda" => true,
      "syslog" => true,
    }.freeze
  )

  def find_unresolved_default_spec(name)
    if msg = DEFAULT_BUNDLED_GEMS.warning?(name)
      warn msg, uplevel: 1
    end
    super
  end
}
