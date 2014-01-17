require "xml"

module Goods
  class XML
    class Validator
      attr_reader :errors

      def initialize(xml)
        @xml = xml
        @errors = []
      end

      def valid?
        validate
        errors.empty?
      end

      private

      def document
        @document ||= LibXML::XML::Document.string(@xml)
      end

      def validate
        errors.clear

        # Should silence STDERR, because libxml2 spews validation error
        # to standard error stream
        silence_stream(STDERR) do
          # Catch first exception due to bug in libxml - it throws
          # 'the model is not determenistic' error. The second validation runs
          # just fine and gives the real error.
          begin
            document.validate(dtd)
          rescue LibXML::XML::Error => e
            #nothing
          end

          begin
            document.validate(dtd)
          rescue LibXML::XML::Error => e
            errors << e.to_s
          end
        end
      end

      def dtd_path
        File.expand_path("../../../support/shops.dtd", __FILE__)
      end

      def dtd_string
        File.read(dtd_path)
      end

      def dtd
        @dtd ||= LibXML::XML::Dtd.new(dtd_string)
      end

      def silence_stream(stream)
        old_stream = stream.dup
        stream.reopen(RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ ? 'NUL:' : '/dev/null')
        stream.sync = true
        yield
      ensure
        stream.reopen(old_stream)
      end
    end
  end
end

