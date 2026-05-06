# typed: true
# frozen_string_literal: true

class ImportChunkJobFactory
  class << self
    def build(chunk)
      case chunk.file_import.input_kind
      when "csv"
        CsvChunkJob.new(chunk.id)
      when "binary"
        BinaryChunkJob.new(chunk.id)
      else
        raise ArgumentError, "unknown input_kind: #{chunk.file_import.input_kind.inspect}"
      end
    end
  end
end
