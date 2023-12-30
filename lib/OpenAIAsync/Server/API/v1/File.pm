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
        handle => async sub($req, $ctx, $obj, $params) {await $self->file_upload($obj, $req, $ctx)},
        request_class => "OpenAIAsync::Type::Request::FileUpload",
        result_class => "OpenAIAsync::Type::Shared::File",
        decoder => 'www-form-urlencoded', # default is json, we need this for this api
    );
    $self->register_url(
        method => 'GET',
        url => qr{^/v1/files/(?<file_id>[^/]+)/content$}, 
        handle => async sub($req, $ctx, $obj, $params) {await $self->file_download($obj, $req, $ctx, $params)},
        request_class => "", # No req type here
        result_class => "", # TODO this should be special, it's raw content, make it undef? leave it off?
    );
    $self->register_url(
        method => 'GET',
        url => qr{^/v1/files/(?<file_id>[^/]+)$}, 
        handle => async sub($req, $ctx, $obj, $params) {await $self->file_info($obj, $req, $ctx, $params)},
        request_class => "", # No req type here
        result_class => "OpenAIAsync::Type::Shared::File",
    );
    $self->register_url(
        method => 'DELETE',
        url => qr{^/v1/files/(?<file_id>[^/]+)$}, 
        handle => async sub($req, $ctx, $obj, $params) {await $self->file_delete($obj, $req, $ctx, $params)},
        request_class => "", # No req type here        
        result_class => "OpenAIAsync::Type::Results::FileDeletion",
    );
    $self->register_url(
        method => 'GET',
        url => qr{^/v1/files$}, 
        handle => async sub($req, $ctx, $obj, $params) {await $self->file_list($obj, $req, $ctx)},
        request_class => "OpenAIAsync::Type::Request::FileList",
        result_class => "OpenAIAsync::Type::Results::FileList",
        decoder => 'optional_json', # this API input is OPTIONAL, if it's not present then we create a blank object to use.
    );
  }

  async method file_list($http_req, $ctx) {...}
  async method file_info($http_req, $ctx, $params) {...}
  async method file_delete($http_req, $ctx, $params) {...}
  async method file_upload($http_req, $ctx, $params) {...}
  async method file_download($http_req, $ctx, $params) {...}
}