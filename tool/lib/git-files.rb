#!/usr/bin/ruby
def git_files(*patterns, git: "git")
  return [] if patterns.empty?
  IO.popen(%W[#{git} ls-files -z] + patterns, err: IO::NULL) {|f|
    f.readlines("\0", chomp: true)
  }
rescue
  []
end

def git_files_check(*patterns, **kwds, &block)
  e = true
  git_files(*patterns, **kwds).each do |n|
    i = 0
    File.foreach(n, binmode: true) do |l|
      i += 1
      unless yield l
        e = false
        warn "#{n}:#{i}:#{l}"
      end
    end
  end
  e
end
