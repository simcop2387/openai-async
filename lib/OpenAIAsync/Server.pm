package OpenAIAsync::Server;

use v5.36.0;
use Object::Pad;
use IO::Async::SSL; # We're not directly using it but I want to enforce that we pull it in when detecting dependencies, since openai itself is always https
use Future::AsyncAwait;
use IO::Async;

use OpenAIAsync::Types::Results;
use OpenAIAsync::Types::Requests;

our $VERSION = '0.02';

# ABSTRACT: Async server for OpenAI style REST API for various AI systems (LLMs, Images, Video, etc.)

=pod

=head1 NAME

OpenAIAsync::Server - IO::Async based server for OpenAI compatible APIs

=head1 SYNOPSIS

  use IO::Async::Loop;
  use OpenAIAsync::Server;
  use builtin qw/true false/;

  my $loop = IO::Async::Loop->new();

  class MyServer {
    inherit OpenAIAsync::Server;

    method init() {
      # We return the info on where we should be listening, and any other settings for Net::Async::HTTP::Server

      return [
        {
          port => "8085",
          listen => "127.0.0.1",
          ...
        },
        ...
      ];
    }

    async method auth_check($key, $http_req) {
      # we can implement any auth checks that we need here
      return true; # AIs need to be free!
    }

    async method chat_completion($chat_completion_req) {
      ...

      return $chat_completion_response;
    }

    ...
  }

  my $server = MyServer->new();

  $loop->add($server);

  $loop->run()

=head1 THEORY OF OPERATION

This module implements the L<IO::Async::Notifier> interface, this means that you create a new server and then call C<< $loop->add($client) >>
this casues all L<Future>s that are created to be part of the L<IO::Async::Loop> of your program.  This way when you call C<await> on any method
it will properly suspend the execution of your program and do something else concurrently (probably waiting on requests).

All the methods that you provide must be async, this is so that multiple requests can be easily handled internally with ease.

You subclass the ::Server class and implement your own methods for handling the limited number of requests, and provide some
configuration information for the servers to start in the configure() method.  The reason to put this into a method is so that
The server object can handle reloading itself without being recreated.  This way any sockets that are already listening don't have
to be closed and reopened to be reconfigured (assuming that the new configuration keeps them open).

Streaming from ::Server is still being designed, I'll publish this system WITHOUT streaming support the first time around
since I need to write at least a new http client module that supports it in order to test things properly, and the make OpenAIAsync::Client
work with streaming events anyway.

=head1 Methods

=head2 new()

Create a new OpenAIAsync::Server.  You'll need to register the server with C<< $loop->add($server) >> after creation.

=head3 PARAMETERS

=over 4

=item * ?

TODO FILL IN

=back

=head2 init($loop)

The intialization phase, this happens before the configure() method is called, so that you can setup any local data stores and validate
the environment.  This will only be called once, but configure() may be called multiple times, such as from a signal handler (SIGHUP or SIGUSR1?)
to reload any configuration for the HTTP endpoints.

Not completely sure if I should have these separated but I kept not liking doing it all in one method for some reason.  Maybe fold this into BUILD {} instead?

=back

=head2 configure($loop)

The configuration phase, returns a list of the arguments to be given to Net::Async::HTTP::Server

TODO bring in some docuemtation, this is derived from C<IO::Async::Loop> 's listen method, and we also need to refer to the connect method for more details
basically, just C<< listen => [addr => '::1', port => 8080, socktype => 'stream'] >> as a basic example.

We handle multiple of these so we can have this proxy listen on multiple ports, and then handle any other behavior for it

The context key will be passed to all of the methods doing the handling here, so you can use it for static data based on which
connection actually was used.  This should help handle multiple networks/vlans or auth patterns a bit easier from a single daemon.

I think this should also let you pass in a listening handle from another module like IO::Socket::SSL or something to do native SSL
But I'm not going to be testing that for some time myself, and would recommend using something else like nginx, haproxy, etc. as a
terminator for TLS connections

    [
      {
        listen => {addrs => ['::1', ...], ...},
        context => {...}
        on_something => code    
      },
      ...
    ]

=back

=head2 async auth_check($key, $ctx, $http_req)

This method requres async keyword.

Return a true or false value on if a request should be authorized.  This is given the API-Key value from the Authorization header

if $key is undef then you can use the $http_req object to get a look at the full headers, so you can implement whatever other authorization system you need

By default all OpenAI compatible APIs are expecting ONLY an API-Key type Authorization header so doing anytyhing else isn't strictly compatible but there's no reason that this server shouldn't be able to do more if you're customizing things

=head2 async completion($ctx, $completion)

=head3 DEPRECATED

This method requres async keyword.

Handle a completion request, takes in a request object, must return a response object.

=head2 async chat($ctx, $chat_completion)

This method requres async keyword.

Handle a chat completion request

=head2 async embedding($ctx, $embedding)

This method requres async keyword.

Handle an embedding request

=head2 async image_generate($ctx, $image_req)

This method requres async keyword.

Unimplemented, but once present will be used to generate images with Dall-E (or for self hosted, stable diffusion).

=head2 async text_to_speech($ctx, $tts_req)

This method requres async keyword.

Unimplemented, but can be used to turn text to speech using whatever algorithms/models are supported.

=head2 async speech_to_text($ctx, $stt_req)

This method requres async keyword.

Unimplemented. The opposite of the above.

=head2 async vision($ctx, $vision_req)

This method requres async keyword.

Unimplemented, I've not investigated this one much yet but I believe it's to get a description of an image and it's contents.

=head2 Missing apis

At least some for getting the list of models and some other meta information, those will be added next after I get some more documentation written

=head1 SERVER SENT EVENTS

Design for this is pending, I'll end making this use new methods, i.e. C<stream_chat_completion>, etc.  These will take in a new $stream object, that can have an event written to it which will be sent without closing the connection.
This is mostly because using this as a proxy will require handling a different kind of client to call another OpenAI endpoint which will necessitate a loop inside
the method that is handling the other end.

=head1 See Also

L<IO::Async>, L<Future::AsyncAwait>, L<Net::Async::HTTP>

=head1 License

Artistic 2.0

=head1 Author

Ryan Voots, ... etc.

=cut

class OpenAIAsync::Server :repr(HASH) :isa(IO::Async::Notifier) :strict(params) {
  use JSON::MaybeXS qw//;
  use Net::Async::HTTP::Server;
  use Feature::Compat::Try;
  use URI;

  field $_json = JSON::MaybeXS->new(utf8 => 1, convert_blessed => 1);
  field $http_servers;

  # TODO document these directly, other options gets mixed in BEFORE all of these
  field $io_async_notifier_params :param = undef;

  method configure(%params) {
    # We require them to go this way, so that there is no conflicts
    # TODO document this
    my %io_async_params = ($params{io_async_notifier_params} // {})->%*;
    IO::Async::Notifier::configure($self, %io_async_params);
  }

  method __make_http_server($port, $listen, $ctx, %args) {
    # TODO args?
    my $server_id = sprintf("%d\0%d", $listen, $port);
    $ctx->{server_id} = $server_id;

    my $httpserver = Net::Async::HTTP::Server->new(
      on_request => sub($httpself, $req) {
        my $f = $self->loop->new_future();

        my $async_f = $self->_route_request($httpself, $req, $ctx);
        $f->on_done($async_f);
        $self->adopt_future($async_f);

        $f->done();
      }
    );

    $http_servers->{$server_id} = {server => $httpserver, ctx => $ctx};

    $self->loop->add($httpserver);
  }

  ADJUST {
  }

  method _resp_custom($req, $code, $str, $json = 0) {
    my $response = HTTP::Response->new( $code );
    $response->content_type('text/plain') unless $json;
    $response->content_type('application/json') if $json;
    $response->add_content($str);
    $response->content_length(length $str);
    $req->respond($response);
  }

  # Pulled out into another method to let subclasses override things if they REALLY want to
  method _get_routes($httpserver, $req, $ctx) {
    my $routers = {
      '/' => {
        GET => async sub {$self->_resp_custom($req, 200, "I'm an AI teapot")},
      },
      '/v1/'.OpenAIAsync::Types::Requests::ChatCompletion->_endpoint() => {
        POST => async sub {$self->_handle_req($httpserver, $req, $ctx, "ChatCompletion")}
      },
      '/v1/'.OpenAIAsync::Types::Requests::Completion->_endpoint() => {
        POST => async sub {$self->_handle_req($httpserver, $req, $ctx, "Completion")}
      },
      '/v1/'.OpenAIAsync::Types::Requests::Embedding->_endpoint() => {
        POST => async sub {$self->_handle_req($httpserver, $req, $ctx, "Embedding")}
      },
    };

    return $routers;
  }

  async method _route_request($httpserver, $req, $ctx) {
    my $routers = $self->_get_routers($httpserver, $req, $ctx);

    my $method = $req->method();
    my $uri    = URI->new($req->uri);
    my $path   = $uri->path;

    try {
      if (my $route = $routers->{$path}) {
        if (my $method_route = $route->{$method}) {
          my $f = Future->wrap($method_route->());
          $self->adopt_future($f);
          return $f;
        } else {
          $self->_resp_custom($req, 405, "Not allowed");
        }
      } else {
        my $f = await $self->route_request($httpserver, $req, $ctx);
        $self->adopt_future($f);
        return $f;
      }
    } catch {
      my $err = $@;

      my $f = Future->wrap($self->_resp_custom($req, 400, "Error: ".$err));
      $self->adopt_future($f);
      return $f;
    }
  }

  async method route_request($httpserver, $req, $ctx) {
    # Base implementation, override in your subclass to do more advanced things
    $self->_resp_custom($req, 404, "Not found");
  }

  # TODO decide if I need this for this setup? I think I don't.
#   method _add_to_loop($loop) {
#    $loop->add($http);
#  }
#
#  method _remove_from_loop($loop) {
#    $loop->remove($http);
#    $http = $self->__make_http; # overkill? want to make sure we have a clean one
#  }

  method _decode_req($req, $kind) {
    my $content_type = $req->header("Content-Type");

    die "Wrong Content Type '$content_type'" unless $content_type eq 'application/json';

    my $raw_content = $req->decoded_content();
    my $json = $_json->decode($raw_content);

    if ($kind eq 'ChatCompletion') {
      return OpenAIAsync::Types::Requests::ChatCompletion->new($json);
    } elsif ($kind eq 'Completion') {
      return OpenAIAsync::Types::Requests::Completion->new($json);
    } elsif ($kind eq 'Embedding') {
      return OpenAIAsync::Types::Requests::Embedding->new($json);
    } else {
      die "Failed to handle kind $kind";
    }
  }

  method _check_response($req, $kind, $content) {

    return $kind eq 'ChatCompletion' ? $content isa OpenAIAsync::Types::Results::ChatCompletion :
           $kind eq 'Completion'     ? $content isa OpenAIAsync::Types::Results::Completion :
           $kind eq 'Embedding'      ? $content isa OpenAIAsync::Types::Results::Embedding :
                                       false;
  }

  async method _handle_req($httpserver, $req, $ctx, $kind) {
    my $authed_f = await $self->auth_check($api_key, $ctx, $req);

    if (not $authed_f->get()) {
      # Not authorized, give a 403
      $self->_resp_custom($req, 403, "Forbidden");
      my $dummy_f = $self->loop->new_future();
      $dummy_f->done();
      return $dummy_f;
    }

    my $obj = $self->_decode_req($req, $kind);

    if ($obj->can('stream')) {
      die "Streaming is unsupported" if $obj->stream;
    }

    my $f;

    if ($kind eq 'ChatCompletion') {
      $f = await $self->chat($ctx, $obj);
    } elsif ($kind eq 'Completion') {
      $f = await $self->completion($ctx, $obj);
    } elsif ($kind eq 'ChatCompletion') {
      $f = await $self->embeddding($ctx, $obj);
    } else {
      die "Unhandled kind $kind";
    }

    $self->adopt_future($f);
    my $resp = $f->get();
    die "Bad response $obj" unless $self->_check_response($req, $kind, $resp);

    my $json_resp = $_json->encode($resp);
    $self->_custom_resp($req, 200, $json_resp, 1);
    return $f;    
  }
}