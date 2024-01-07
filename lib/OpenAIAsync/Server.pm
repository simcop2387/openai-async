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

class OpenAIAsync::Server :repr(HASH) :strict(params) {
  inherit IO::Async::Notifier;

  use JSON::MaybeXS qw//;
  use Net::Async::HTTP::Server;
  use Feature::Compat::Try;
  use URI;
  use WWW::Form::UrlEncoded;
  no warnings 'experimental';
  use builtin qw/true false/;
  use Hash::Merge;
  use HTTP::Response;
  use HTTP::Request;

  field $_json = JSON::MaybeXS->new(utf8 => 1, convert_blessed => 1);
  field $http_server;

  field $port :param = "8080";
  field $listen :param = "127.0.0.1";
  field $ctx :param = {};
  field $httpserver_args :param = {}; # by default nothing

  # TODO document these directly, other options gets mixed in BEFORE all of these
  field $io_async_notifier_params :param = undef;

  method configure(%params) {
    # We require them to go this way, so that there is no conflicts
    # TODO document this
    my %io_async_params = ($params{io_async_notifier_params} // {})->%*;
    IO::Async::Notifier::configure($self, %io_async_params);
  }

  method __make_http_server() {
    # TODO args?
    # TODO make this work during a reload
    my $server_id = sprintf("%s\0%d", $listen, $port);
    $ctx->{server_id} = $server_id;

    $http_server = Net::Async::HTTP::Server->new(
      $httpserver_args->%*,
      on_request => sub($httpself, $req) {
        my $async_f = $self->_route_request($req, $ctx);
        $self->adopt_future($async_f);
      }
    );

    $self->loop->add($http_server);

    my $merger = Hash::Merge->new('LEFT_PRECEDENT');

    my $http_args = $merger->merge($httpserver_args, {addr => {socktype => "stream", port => $port, ip => $listen, family => "inet"}});

    $http_server->listen($http_args->%*)->get();
  }

  method _add_to_loop {
    $self->__make_http_server();
  }

  method _resp_custom($req, $code, $str, $json = 0) {
    my $response = HTTP::Response->new( $code );
    $response->content_type('text/plain') unless $json; # TODO this needs to be more flexible due to audio outputs
    $response->content_type('application/json') if $json;
    $response->add_content($str);
    $response->content_length(length $str);
    $req->respond($response);
  }

  field $routes = [];

  method register_url(%opts) {
    # TODO check params
    use Data::Dumper;
    say Dumper("Got url registered", \%opts);
    push $routes->@*, \%opts;
  }

  async method _route_request($req, $ctx) {
    my $method = $req->method();
    my $path   = $req->path;

    say "Got request ", $method, " => ", $path;

    try {
      my $found_route = false;
      my $f;
      for my $route ($routes->@*) {
        if ($path =~ $route->{url} && $route->{method} eq $method) {
          my $params = +{%+, _ => [@+]}; # make a copy of named parameters, and digited ones to pass into the handler
          $found_route = true;
          say "Found path $route->{url}";

          my $obj;
          if ($route->{decoder} eq "www-form-urlencoded") {
            my %data = WWW::Form::UrlEncoded::parse_urlencoded($req->decoded_content);
            $obj = $route->{request_class}->new(%data);
          } elsif ($route->{decoder} eq "json") {
            my $data = $_json->decode($req->decoded_content);
            $obj = $route->{request_class}->new(%$data);
          } elsif ($route->{decoder} eq "null") {
            $obj = $route->{request_class}->new();
          } else { # Try to detect based on content-type, then fail
            my $content_type = $req->header("Content-Type");
            if ($content_type eq 'application/json') {
              my $data = $_json->decode($req->decoded_content);
              $obj = $route->{request_class}->new(%$data);
            } elsif ($content_type eq 'application/x-www-form-urlencoded') {
              my %data = WWW::Form::UrlEncoded::parse_urlencoded($req->decoded_content);
              $obj = $route->{request_class}->new(%data);
            } else {
              die "Unsupported content-type for URI: $content_type";
            }
          }

          try {
            my ($result, @extra) = (await $route->{handle}->($req, $ctx, $obj, $params))->get();
            
            if ($route->{result_class}) {
              my $out_obj = $result;
              unless ($out_obj isa $route->{result_object}) {
                $out_obj = $route->{result_class}->new(%$result);
              }

              if (@extra) {
                $self->_resp_custom($req, $extra[0], $out_obj); # TODO better design?
              } else {
                $self->_resp_custom($req, 200, $out_obj);
              }
            } else {
              if (@extra) {
                $self->_resp_custom($req, @extra); # TODO better design?
              } else {
                # Nothing to output directly
                $self->_resp_custom($req, 200, "");
              }

              return;
            }
          } catch($err) {
            $self->_resp_custom($req, 500, "Server error: ".$err);
            return;
          }
        }
      }

      unless ($found_route) {
        $self->_resp_custom($req, 404, "Not found");
      }
    } catch($err) {
      $self->_resp_custom($req, 400, "Error: ".$err);
    }
  }
}