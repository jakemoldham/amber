require "tempfile"
require "./*"
# The Context holds the request and the response objects.  The context is
# passed to each handler that will read from the request object and build a
# response object.  Params and Session hash can be accessed from the Context.
class HTTP::Server::Context
  include Amber::Router::Files
  include Amber::Router::Session
  include Amber::Router::Flash
  include Amber::Router::Params

  property route : Radix::Result(Amber::Route)
  getter router : Amber::Router::Router
  getter cookies : Amber::Router::Cookies::CookieStore

  def initialize(@request : HTTP::Request, @response : HTTP::Server::Response)
    @router = Amber::Router::Router.instance
    @cookies = Amber::Router::Cookies::CookieStore.build(request, Server.settings.secret)
    parse_params
    upgrade_request_method!
    @route = router.match_by_request(@request)
    merge_route_params
  end

  def invalid_route?
    !route.payload?
  end

  def websocket?
    request.headers["Upgrade"]? == "websocket"
  end

  def request_handler
    route.payload
  end

  def process_websocket_request
    router.get_socket_handler(request).call(self)
  end

  def process_request
    request_handler.call(self)
  end

  def valve
    request_handler.valve
  end
end
