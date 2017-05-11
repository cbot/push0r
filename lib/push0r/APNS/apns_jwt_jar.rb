require 'yaml'

module Push0r
  module APNS
    class JWTJar
      attr_accessor :jwt, :jwt_created_at

      def initialize
        @jwt = nil
        @jwt_created_at = nil
      end

      # @param [String] key_id
      def load_data(key_id)
        # empty implementation
      end
    end

    class JWTSimpleJar < JWTJar
      def initialize(path = nil)
        super()
        @path = path
      end

      # @param [String] key_id
      def load_data(key_id)
        super(key_id)

        filename = "jwt_jar_#{key_id}.yaml"
        if @path.nil?
          @yaml_path = filename
        else
          @yaml_path = File.join(@path, filename)
        end

        if File.exists?(@yaml_path)
          begin
            hash = YAML.load(File.read(@yaml_path))
            @jwt = hash[:jwt]
            @jwt_created_at = hash[:jwt_created_at]
          rescue StandardError => e
            puts "Failed to load JWT data: #{e}"
          end
        end
      end

      def jwt=(new_value)
        @jwt = new_value
        save
      end

      def jwt_created_at=(new_value)
        @jwt_created_at = new_value
        save
      end

      private
      def save
        return if @yaml_path.nil?

        begin
          File.write(@yaml_path, YAML.dump({jwt: @jwt, jwt_created_at: @jwt_created_at}))
        rescue StandardError => e
          puts "Failed to save JWT data: #{e}"
        end
      end
    end
  end
end