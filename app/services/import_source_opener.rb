# typed: true
# frozen_string_literal: true

class ImportSourceOpener
  class << self
    def call(file_import, &block)
      new(file_import).call(&block)
    end
  end

  def initialize(file_import)
    @file_import = file_import
  end

  def call
    mode = @file_import.binary? ? "rb" : "r:bom|utf-8"
    @file_import.source_file.open { |tempfile| File.open(tempfile.path, mode) { |io| yield io } }
  end
end
