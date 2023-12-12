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
configuration information for the servers to start in the init() method


=head1 Methods

=head2 new()

Create a new OpenAIAsync::Server.  You'll need to register the server with C<< $loop->add($server) >> after creation.

=head3 PARAMETERS

=over 4

=item * ?

TODO FILL IN

=back

=head2 auth_check($key, $http_req)

This method requres async keyword.

Return a true or false value on if a request should be authorized.  This is given the API-Key value from the Authorization header

if $key is undef then you can use the $http_req object to get a look at the full headers, so you can implement whatever other authorization system you need

By default all OpenAI compatible APIs are expecting ONLY an API-Key type Authorization header so doing anytyhing else isn't strictly compatible but there's no reason that this server shouldn't be able to do more if you're customizing things

=head2 completion (deprecated)

This method requres async keyword.

Handle a completion request, takes in a request object, must return a response object

=head2 chat

This method requres async keyword.

Handle a chat completion request

=head2 embedding

This method requres async keyword.

Handle an embedding request

=head2 image_generate

This method requres async keyword.

Unimplemented, but once present will be used to generate images with Dall-E (or for self hosted, stable diffusion).

=head2 text_to_speech

This method requres async keyword.

Unimplemented, but can be used to turn text to speech using whatever algorithms/models are supported.

=head2 speech_to_text

This method requres async keyword.

Unimplemented. The opposite of the above.

=head2 vision

This method requres async keyword.

Unimplemented, I've not investigated this one much yet but I believe it's to get a description of an image and it's contents.

=head2 Missing apis

At least some for getting the list of models and some other meta information, those will be added next after I get some more documentation written

=head1 See Also

L<IO::Async>, L<Future::AsyncAwait>, L<Net::Async::HTTP>

=head1 License

Artistic 2.0

=head1 Author

Ryan Voots, ... etc.

=cut

class OpenAIAsync::Client :repr(HASH) :isa(IO::Async::Notifier) :strict(params) {
  use JSON::MaybeXS qw//;
  use Net::Async::HTTP;
  use Feature::Compat::Try;
  use URI;

  field $_json = JSON::MaybeXS->new(utf8 => 1, convert_blessed => 1);
  field $http;

  # TODO document these directly, other options gets mixed in BEFORE all of these
  field $_http_max_in_flight :param(http_max_in_flight) = 2;
  field $_http_max_redirects :param(http_max_redirects) = 3;
  field $_http_max_connections_per_host :param(http_max_connections_per_host) = 2;
  field $_http_timeout :param(http_timeout) = 120; # My personal server is kinda slow, use a generous default
  field $_http_stall_timeout :param(http_stall_timeout) = 600; # generous for my slow personal server
  field $_http_other :param(http_other_options) = {};
  field $_http_user_agent :param(http_user_agent) = __PACKAGE__." Perl/$VERSION (Net::Async::HTTP/".$Net::Async::HTTP::VERSION." IO::Async/".$IO::Async::VERSION." Perl/$])";

  field $api_base :param(api_base) = $ENV{OPENAI_API_BASE} // "https://api.openai.com/v1";
  field $api_key :param(api_key) = $ENV{OPENAI_API_KEY};

  field $api_org_name :param(api_org_name) = undef;

  field $io_async_notifier_params :param = undef;

  method configure(%params) {
    # We require them to go this way, so that there is no conflicts
    # TODO document this
    my %io_async_params = ($params{io_async_notifier_params} // {})->%*;
    IO::Async::Notifier::configure($self, %io_async_params);
  }

  method __make_http() {
    die "Missing API Key for OpenAI" unless $api_key;

    return Net::Async::HTTP->new(
      $_http_other->%*,
      user_agent => "SNN OpenAI Client 1.0",
      +headers => {
        "Authorization" => "Bearer $api_key",
        "Content-Type" => "application/json",
        $api_org_name ? (
          'OpenAI-Organization' => $api_org_name,
        ) : ()
      },
      max_redirects => $_http_max_redirects,
      max_connections_per_host => $_http_max_connections_per_host,
      max_in_flight => $_http_max_in_flight,
      timeout => $_http_timeout,
      stall_timeout => $_http_stall_timeout,
    )
  }

  ADJUST {
    $http = $self->__make_http;

    $api_base =~ s|/$||; # trim an accidental final / since we will be putting it on the endpoints
  }

  async method _make_request($endpoint, $data) {
    my $json = $_json->encode($data);

    my $url = URI->new($api_base . $endpoint );

    my $result = await $http->do_request(
      uri => $url,
      method => "POST",
      content => $json,
      content_type => 'application/json',
    );

    if ($result->is_success) {
      my $json = $result->decoded_content;
      my $out_data = $_json->decode($json);

      return $out_data;
    } else {
      die "Failure in talking to OpenAI service: ".$result->status_line.": ".$result->decoded_content;
    }
  }

   method _add_to_loop($loop) {
    $loop->add($http);
  }

  method _remove_from_loop($loop) {
    $loop->remove($http);
    $http = $self->__make_http; # overkill? want to make sure we have a clean one
  }

  # This is the legacy completion api
  async method completion($input) {

    if (ref($input) eq 'HASH') {
      $input = OpenAIAsync::Types::Requests::Completion->new($input->%*);
    } elsif (ref($input) eq 'OpenAIAsync::Types::Requests::Completion') {
      # dummy, nothing to do
    } else {
      die "Unsupported input type [".ref($input)."]";
    }

    my $data = await $self->_make_request($input->_endpoint(), $input);

    my $type_result = OpenAIAsync::Types::Results::Completion->new($data->%*);

    return $type_result;
  }

  async method chat($input) {
    if (ref($input) eq 'HASH') {
      $input = OpenAIAsync::Types::Requests::ChatCompletion->new($input->%*);
    } elsif (ref($input) eq 'OpenAIAsync::Types::Requests::ChatCompletion') {
      # dummy, nothing to do
    } else {
      die "Unsupported input type [".ref($input)."]";
    }

    my $data = await $self->_make_request($input->_endpoint(), $input);

    my $type_result = OpenAIAsync::Types::Results::ChatCompletion->new($data->%*);

    return $type_result;
  }

  async method embedding($input) {
    if (ref($input) eq 'HASH') {
      $input = OpenAIAsync::Types::Requests::Embedding->new($input->%*);
    } elsif (ref($input) eq 'OpenAIAsync::Types::Requests::Embedding') {
      # dummy, nothing to do
    } else {
      die "Unsupported input type [".ref($input)."]";
    }

    my $data = await $self->_make_request($input->_endpoint(), $input);

    my $type_result = OpenAIAsync::Types::Results::Embedding->new($data->%*);

    return $type_result;
  }

  async method image_generate($input) {
    ...
  }

  async method text_to_speech($text) {
    ...
  }

  async method speech_to_text($sound_data) {
    ...
  }

  async method vision($image, $prompt) {
    ...
  }
}