# frozen_string_literal: true

require "subprocess"

module Stripe
  class StripeMock
    include Singleton

    @process = nil
    @port = -1

    # Starts stripe-mock, if necessary. Returns the port on which stripe-mock is listening.
    def self.start
      if ENV.key?("STRIPE_MOCK_PORT")
        puts("STRIPE_MOCK_PORT is set, assuming stripe-mock is already running on port #{ENV['STRIPE_MOCK_PORT']}")
        return ENV["STRIPE_MOCK_PORT"].to_i
      end

      unless @process.nil?
        puts("stripe-mock already running on port #{@port}")
        return @port
      end

      if RUBY_PLATFORM == "java"
        abort("stripe-mock doesn't appear to be running and JRuby cannot fork new processes. Start stripe-mock manually and set STRIPE_MOCK_PORT to the HTTP port.")
      end

      @port = find_available_port

      puts("Starting stripe-mock on port #{@port}...")

      @process = Subprocess.popen(
        [
          "stripe-mock",
          "-http-port",
          @port.to_s,
          "-spec",
          "#{::File.dirname(__FILE__)}/openapi/spec3.json",
          "-fixtures",
          "#{::File.dirname(__FILE__)}/openapi/fixtures3.json",
        ],
        stdout: Subprocess::PIPE,
        stderr: Subprocess::PIPE
      )
      sleep 1

      status = @process.poll
      if status.nil?
        puts("Started stripe-mock, PID = #{@process.pid}")
      else
        abort("stripe-mock terminated early: #{status}")
      end

      @port
    end

    # Stops stripe-mock, if necessary.
    def self.stop
      return if @process.nil?
      puts("Stopping stripe-mock...")
      @process.terminate
      @process.wait
      @process = nil
      @port = -1
      puts("Stopped stripe-mock")
    end

    # Finds and returns an available TCP port
    private_class_method def self.find_available_port
      server = TCPServer.new("localhost", 0)
      port = server.addr[1]
      server.close
      port
    end
  end
end
