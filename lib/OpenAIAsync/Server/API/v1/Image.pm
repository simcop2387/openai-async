package OpenAIAsync::Server::API::v1::Image;

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

OpenAIAsync::Server::API::Image - Basic image role, consumed to implement the OpenAI image api.  Does not provide an implementation, you are expected to override them in your class

=head1 SYNOPSIS

...

=cut

role OpenAIAsync::Server::API::v1::Image :strict(params) {
  ADJUST {
    $self->register_url(
        method => 'GET',
        url => qr{^/v1/files$}, 
        handle => async sub($req, $ctx, $obj, $params) {await $self->create_image($obj, $req, $ctx)},
        request_class => "OpenAIAsync::Type::Requests::",
        result_class => "OpenAIAsync::Type::Results::FileList",
        decoder => 'optional_json', # this API input is OPTIONAL, if it's not present then we create a blank object to use.
    );
  }

  async method create_image($http_req, $ctx) {...}
}