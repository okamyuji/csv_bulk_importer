# frozen_string_literal: true

# 使い方: ruby script/bench/gen_image.rb <サイズMB> <出力パス>
# 例:    ruby script/bench/gen_image.rb 5   tmp/bench/img_small.jpg
#        ruby script/bench/gen_image.rb 300 tmp/bench/img_large.jpg
#
# Marcel に JPEG として認識される SOI マーカ付きの合成バイナリを生成する。

require "fileutils"

size_mb = Integer(ARGV[0])
out     = ARGV[1]
FileUtils.mkdir_p(File.dirname(out))

magic = "\xFF\xD8\xFF\xE0".b
chunk = (0...8192).map { |i| ((i * 31 + 7) & 0xFF).chr }.join.b

File.open(out, "wb") do |f|
  f.write(magic)
  remaining = (size_mb * 1024 * 1024) - magic.bytesize
  while remaining.positive?
    n = [chunk.bytesize, remaining].min
    f.write(chunk.byteslice(0, n))
    remaining -= n
  end
end
puts "size=#{File.size(out)} path=#{out}"
