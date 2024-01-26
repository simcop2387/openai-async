package OpenAIAsync::Server::API::v1::ChatCompletion;

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

role OpenAIAsync::Server::API::v1::ChatCompletion :strict(params) {
  use Future::AsyncAwait;

  ADJUST {
    $self->register_url(
        method => 'POST',
        url => qr{^/v1/chat/completions$}, 
        handle => async sub($req, $ctx, $obj, $params) {await $self->chat($obj, $req, $ctx)},
        request_class => "OpenAIAsync::Type::Request::ChatCompletion",
        result_class => "OpenAIAsync::Type::Result::ChatCompletion",
        decoder => 'www-form-urlencoded', # default is json, we need this for this api
    );
  }

  async method chat($obj, $http_req, $ctx);
}