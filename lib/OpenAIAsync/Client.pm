package OpenAIAsync::Client;

use v5.36.0;
use Object::Pad;
use IO::Async::SSL; # We're not directly using it but I want to enforce that we pull it in when detecting dependencies, since openai itself is always https
use Future::AsyncAwait;
use IO::Async;

use OpenAIAsync::Types::Results;
use OpenAIAsync::Types::Requests;

our $VERSION = '0.02';

# ABSTRACT: Async client for OpenAI style REST API for various AI systems (LLMs, Images, Video, etc.)

=pod

=head1 NAME

OpenAIAsync::Client - IO::Async based client for OpenAI compatible APIs

=head1 SYNOPSIS

  use IO::Async::Loop;
  use OpenAIAsync::Client;

  my $loop = IO::Async::Loop->new();

  my $client = OpenAIAsync::Client->new();

  $loop->add($client);

  my $output = await $client->chat({
      model => "gpt-3.5-turbo",
      messages => [
        {
          role => "system",
          content => "You are a helpful assistant that tells fanciful stories"
        },
        {
          role => "user",
          content => "Tell me a story of two princesses, Judy and Emmy.  Judy is 8 and Emmy is 2."
        }
      ],



    max_tokens => 1024, 
  })->get();

  # $output is now an OpenAIAsync::Type::Results::ChatCompletion

=head1 THEORY OF OPERATION

This module implements the L<IO::Async::Notifier> interface, this means that you create a new client and then call C<< $loop->add($client) >>
this casues all L<Future>s that are created to be part of the L<IO::Async::Loop> of your program.  This way when you call C<await> on any method
it will properly suspend the execution of your program and do something else concurrently (probably waiting on requests).

=head1 Methods

=head2 new()

Create a new OpenAIAsync::Client.  You'll need to register the client with C<< $loop->add($client) >> after creation.

=head3 PARAMETERS

=over 4

=item * api_base (optional)

Base url of the service to connect to.  Defaults to C<https://api.openai.com/v1>.  This should be a value pointing to something that
implements the v1 OpenAI API, which for OobaBooga's text-generation-webui might be something like C<http://localhost:5000/v1>.

It will also be pulled from the environment variable C<OPENAI_API_BASE> in the same fashion that the OpenAI libraries in other languages will do.

=item * api_key (required)

Api key that will be passed to the service you call.  This gets passed as a header C<Authorization: Api-Key ....> to the service in all of the REST
calls.  This should be kept secret as it can be used to make all kinds of calls to paid services.

It will also be pulled from the environment variable C<OPENAI_API_KEY> in the same fashion that the OpenAI libraries in other languages will do.

=item * api_org_name (optional)

A name for the organization that's making the call.  This can be used by OpenAI to help identify which part of your company is
making any specific request, and I believe to help itemize billing and other tasks. 

=item * http_user_agent (optional)

Set the useragent that's used to contact the API service.  Defaults to 

C<< __PACKAGE__." Perl/$VERSION (Net::Async::HTTP/".$Net::Async::HTTP::VERSION." IO::Async/".$IO::Async::VERSION." Perl/$])" >>

The default is to make it easier to debug if we ever see weird issues with the requests being generated but it does reveal some information
about the code environment.

=item * http_max_in_flight (optional)

How many requests should we allow to happen at once.  Increasing this will increase the allowed parallel requests, but that can also
allow you to make too many requests and cost more in API calls.

Defaults to 2

=item * http_max_connections_per_host (optional)

TODO, I'm thinking this one will get dropped.  Effectively since we're only ever connecting to one server this ends up functioning the same as the above parameter.

Defaults to 2

=item * http_max_redirects (optional)

How many redirects to allow.  The official OpenAI API never sends redirects (for now) but for self hosted or other custom setups this might happen and should be handled correctly

Defaults to 3

=item * http_timeout (optional)

How long to wait on any given request to start.  

Defaults to 120 seconds.

=item * http_stall_timeout (optional)

How long to wait on any given request to decide if it's been stalled.  If a request starts responding and then stops part way through, this is how we'll treat it as stalled and time it out

Defaults to 600s (10 minutes).  This is unlikely to happen except for a malfunctioning inference service since once generation starts to return it'll almost certainly finish.

=item * http_other (optional)

A hash ref that gets passed as additional parameters to L<Net::Async::HTTP>'s constructor.  All values will be overriden by the ones above, so if a parameter is supported use those first.

=back

=head2 completion (deprecated)

Create a request for completion, this takes a prompt and returns a response.  See L<OpenAIAsync::Types::Request::Completion> for exact details.

This particular API has been deprecated by OpenAI in favor of doing everything through the chat completion api below.  However it is still supported
by OpenAI and compatible servers as it's a very simple interface to use

=head2 chat

Create a request for the chat completion api.  This takes a series of messages and returns a new chat response.  See L<OpenAIAsync::Types::Request::ChatCompletion> for exact details.

This API takes a series of messages from different agent sources and then responds as the assistant agent.  A typical interaction is to start with a C<"system"> agent message 
to set the context for the assistant, followed by the C<"user"> agent type for the user's request.  You'll then get the response from the assistant agent to give to the user.

To continue the chat, you'd then take the new message and insert it into the list of messages as part of the chat and make a new request with the user's response.  I'll be creating
a new module that uses this API and helps manage the chat in an easier manner with a few helper functions.

=head2 embedding

Create a request for calculating the embedding of an input.  This takes a bit of text and returns a gigantic list of numbers, see L<OpenAIAsync::Types::Request::Embedding> for exact details.

These values are a bit difficult to explain how they work, but essentially you get a mathematical object, a vector, that describes the contents of the input as 
a point in an N-dimensional space (typically 768 or 1536 dimensions).  The dimensions themselves really don't have any inherit mathematical meaning but are instead relative to one-another
from the training data of the embedding model.

You'll want to take the vector and store it in a database that supports vector operations, like PostgreSQL with the L<pgvector|https://github.com/pgvector/pgvector> extension.

=head2 image_generate

Unimplemented, but once present will be used to generate images with Dall-E (or for self hosted, stable diffusion).

=head2 text_to_speech

Unimplemented, but can be used to turn text to speech using whatever algorithms/models are supported.

=head2 speech_to_text

Unimplemented. The opposite of the above.

=head2 vision

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