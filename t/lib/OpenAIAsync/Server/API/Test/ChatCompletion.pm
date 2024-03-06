package OpenAIAsync::Server::API::Test::ChatCompletion;

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

OpenAIAsync::Server::API::ChatCompletion - Basic chat api role, consumed to implement the OpenAI chat completion api.  Does not provide an implementation, you are expected to override them in your class

=head1 SYNOPSIS

...

=cut

role OpenAIAsync::Server::API::Test::ChatCompletion :strict(params) {
  apply OpenAIAsync::Server::API::v1::ChatCompletion;
  use OpenAIAsync::Types::Results;
  use Future::AsyncAwait;
  
  async method chat ($future_status, $queue, $ctx, $obj, $params) {
    my $chained_future = $future_status->then(sub {
      return OpenAIAsync::Types::Results::ChatCompletion->new(
          id => "24601",
          choices => [],
          model => "GumbyBrain-llm",
          system_fingerprint => "SHODAN node 12 of 16 tertiary adjunct of unimatrix 42",
          usage => {
            total_tokens => 42,
            prompt_tokens => 6,
            completion_tokens => 9,
          },
          object => "text_completion",
          created => 0,
        )
      }
    );

    $future_status->done({
      headers => {}, # TODO a way I can make this not leak and not expose the HTTP nature?
      is_streaming => false,
      content_type => "application/json", # TODO this should come from the object return type!
      status_code => 200,
      status_message => "OK",
    });

    return $chained_future; # TODO this might actually be wrong thanks to the async above?
}