package OpenAIAsync::Server::API::v1::File;

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

OpenAIAsync::Server::API::File - Basic file api role, consumed to implement the OpenAI file server.  Does not provide an implementation, you are expected to override them in your class

=head1 SYNOPSIS

...

=cut

role OpenAIAsync::Server::API::v1::File :strict(params) {
  ADJUST {
    $self->register_url(
        method => 'POST',
        url => qr{^/v1/files$}, 
        handle => async sub($req, $ctx, $params) {await $self->file_upload($req, $ctx)},
        result_class => "OpenAIAsync::Type::Shared::File",
    );
    $self->register_url(
        method => 'GET',
        url => qr{^/v1/files/(?<file_id>[^/]+)/content$}, 
        handle => async sub($req, $ctx, $params) {await $self->file_download($req, $ctx, $params)},
        result_class => "", # TODO this should be special, it's raw content, make it undef? leave it off?
    );
    $self->register_url(
        method => 'GET',
        url => qr{^/v1/files/(?<file_id>[^/]+)$}, 
        handle => async sub($req, $ctx, $params) {await $self->file_info($req, $ctx, $params)},
        result_class => "OpenAIAsync::Type::Shared::File",
    );
    $self->register_url(
        method => 'DELETE',
        url => qr{^/v1/files/(?<file_id>[^/]+)$}, 
        handle => async sub($req, $ctx, $params) {await $self->file_delete($req, $ctx, $params)},
        result_class => "OpenAIAsync::Type::Results::FileDeletion",
    );
    $self->register_url(
        method => 'GET',
        url => qr{^/v1/files$}, 
        handle => async sub($req, $ctx, $params) {await $self->file_list($req, $ctx)},
        result_class => "OpenAIAsync::Type::Results::FileList",
    );
  }

  async method file_list($http_req, $ctx) {...}
  async method file_info($http_req, $ctx, $params) {...}
  async method file_delete($http_req, $ctx, $params) {...}
  async method file_upload($http_req, $ctx, $params) {...}
  async method file_download($http_req, $ctx, $params) {...}
}