# Usage: ruby tool/update-NEWS-refs.rb

news_md = File.join(__dir__, "../NEWS.md")
orig_src = File.read(news_md)
lines = orig_src.lines(chomp: true)

while lines.last =~ %r{\A\[GH-(\d+)\]:\s+https://github\.com/ruby/ruby/(?:pull|issue)/\1\z}
  lines.pop
end

while lines.last =~ %r{\A\[(Feature|Bug) #(\d+)\]:\s+https://bugs\.ruby-lang\.org/issues/\2\z}
  lines.pop
end

if lines.last != ""
  raise <<~MESG
  NEWS.md must end with a sequence of links as followings
  * "[Feature #XXXXX]: https://bugs.ruby-lang.org/issues/XXXXX"
  * "[GH-XXXX]: https://github.com/ruby/ruby/pull/XXXXX"
  MESG
end

gh = {}
links = {}
new_src = lines.join("\n").gsub(/\[?\[(?:(Feature|Bug)\s+\#|(GH-))(\d+)\]\]?/) do
  num = $3.to_i
  if type = $1
    links[num] ||= type
    "[[#{type} ##{num}]]"
  else
    gh[num] ||= true
    "[[GH-#{num}]]"
  end
end.chomp + "\n\n"
unless links.empty?
  w = links.max_by {|num, _| num}[0].to_s.size + "[Feature #]: ".size
  new_src += links.sort.map {|num, type| "[#{type} ##{num}]:".ljust(w) + "https://bugs.ruby-lang.org/issues/#{num}\n"}.join("")
end
unless gh.empty?
  w = gh.max_by {|num, _| num}[0].to_s.size + "[GH-]: ".size
  new_src += gh.sort.map {|num, type| "[GH-#{num}]:".ljust(w) + "https://github/ruby/ruby/pull/#{num}\n"}.join("")
end

if orig_src != new_src
  print "Update NEWS.md? [y/N]"
  $stdout.flush
  if gets.chomp == "y"
    File.write(news_md, new_src)
  end
end
