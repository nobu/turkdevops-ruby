require 'mspec/guards/feature'

class IOStub
  def initialize
    @buffer = []
    @output = ''
  end

  def write(*str)
    self << str.join
  end

  def << str
    @buffer << str
    self
  end

  def print(*str)
    write(str.join + $\.to_s)
  end

  def method_missing(name, *args, &block)
    to_s.send(name, *args, &block)
  end

  def == other
    to_s == other
  end

  def =~ other
    to_s =~ other
  end

  def puts(*str)
    if str.empty?
      write "\n"
    else
      write(str.collect { |s| s.to_s.chomp }.concat([nil]).join("\n"))
    end
  end

  def printf(format, *args)
    self << sprintf(format, *args)
  end

  def flush
    @output += @buffer.join('')
    @buffer.clear
    self
  end

  def to_s
    flush
    @output
  end

  alias_method :to_str, :to_s

  def inspect
    to_s.inspect
  end
end

# Creates a "bare" file descriptor (i.e. one that is not associated
# with any Ruby object). The file descriptor can safely be passed
# to IO.new without creating a Ruby object alias to the fd.
def new_fd(name, _mode="w:utf-8", mode: _mode, **)
  IO.sysopen name, mode
end

# Creates an IO instance for a temporary file name. The file
# must be deleted.
def new_io(name, _mode="w:utf-8", mode: _mode, **opts)
  IO.new new_fd(name, mode), mode, **opts
end

def find_unused_fd
  Dir.entries("/dev/fd").map(&:to_i).max + 1
end
