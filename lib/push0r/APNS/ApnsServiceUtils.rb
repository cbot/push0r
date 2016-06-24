module Push0r
  module ApnsServiceUtils
      # @return [String, nil] the first topic from the certificate's 1.2.840.113635.100.6.3.6 extension
      # @param [Object] the push certificate data
      def extract_first_topic_from_certificate(certificate_data)
      if certificate_data.nil?
        puts 'Unable to extract topic from certificate - certificate missing'
        return
      end

      begin
        cert = OpenSSL::X509::Certificate.new(certificate_data)
      rescue StandardError => e
        puts "OpenSSL error: #{e}"
        return
      end

      extension = cert.extensions.select { |e| e.oid == '1.2.840.113635.100.6.3.6' }.first
      if extension.nil?
        puts 'Unable to extract topic from certificate - missing certificate extension'
        return nil
      end

      topic = nil
      begin
        extension_node = OpenSSL::ASN1.decode(extension)
        if extension_node.is_a?(OpenSSL::ASN1::Sequence)
          extension_node.each do |subnode|
            if subnode.is_a?(OpenSSL::ASN1::OctetString)
              sequence_node = OpenSSL::ASN1.decode(subnode.value)
              if sequence_node.is_a?(OpenSSL::ASN1::Sequence)
                sequence_node.each do |data_node|
                  if data_node.value.is_a?(String)
                    topic = data_node.value
                    break
                  end
                end
              end
            end
          end
        end
      rescue StandardError => e
        puts "OpenSSL Error: #{e}"
      end

      puts 'Unable to extract topic from certificate - could not parse data' if topic.nil?

      topic
    end
  end
end