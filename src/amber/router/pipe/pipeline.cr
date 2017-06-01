module Amber
  module Pipe
    # This class picks the correct pipeline based on the request
    # and executes it.
    class Pipeline < Base
      getter pipeline
      getter valve : Symbol
      getter router
      getter pipes

      def self.instance
        @@instance ||= new
      end

      def initialize
        @router = Router::Router.instance
        @valve = :web
        @pipeline = {} of Symbol => Array(HTTP::Handler)
        @pipeline[@valve] = [] of HTTP::Handler
        @pipes = Hash(Symbol, (HTTP::Handler | Nil | (HTTP::Server::Context ->))).new(nil)
      end

      def call(context : HTTP::Server::Context)
        if context.request.headers["Upgrade"]? === "websocket"
          @router.get_socket_handler(context.request).call(context)
        else
          raise Exceptions::RouteNotFound.new(context.request) if validate_route(context)
          route = context.route.payload
          valve = route.valve
          pipes[valve] ||= proccess_pipeline(@pipeline[route.valve], ->(context : HTTP::Server::Context) { context })
          pipes[valve].not_nil!.call(context) if pipes[valve]
          context.response.print(route.call(context))
          context
        end
      end

      def validate_route(context)
        !router.route_defined?(context.request)
      end

      # Connects pipes to a pipeline to process requests
      def build(valve : Symbol, &block)
        @valve = valve
        @pipeline[@valve] = [] of HTTP::Handler unless @pipeline.key? @valve
        with DSL::Pipeline.new(self) yield
      end

      def plug(pipe : HTTP::Handler)
        @pipeline[@valve] << pipe
      end

      def proccess_pipeline(pipes, last_pipe : (HTTP::Server::Context ->)? = nil)
        if pipes.any?
          0.upto(pipes.size - 2) { |i| pipes[i].next = pipes[i + 1] }
          pipes.last.next = last_pipe if last_pipe
          pipes.first
        elsif last_pipe
          last_pipe
        end
      end
    end
  end
end
