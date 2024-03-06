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
        handle => "file_upload",
        request_class => "OpenAIAsync::Type::Request::FileUpload",
        result_class => "OpenAIAsync::Type::Shared::File",
        decoder => 'www-form-urlencoded', # default is json, we need this for this api
    );
    $self->register_url(
        method => 'GET',
        url => qr{^/v1/files/(?<file_id>[^/]+)/content$}, 
        handle => "file_download",
        request_class => "", # No req type here
        result_class => "OpenAIAsync::Type::Results::RawFile",
    );
    $self->register_url(
        method => 'GET',
        url => qr{^/v1/files/(?<file_id>[^/]+)$}, 
        handle => "file_info",
        request_class => "", # No req type here
        result_class => "OpenAIAsync::Type::Shared::File",
    );
    $self->register_url(
        method => 'DELETE',
        url => qr{^/v1/files/(?<file_id>[^/]+)$}, 
        handle => "file_delete",
        request_class => "", # No req type here        
        result_class => "OpenAIAsync::Type::Results::FileDeletion",
    );
    $self->register_url(
        method => 'GET',
        url => qr{^/v1/files$}, 
        handle => "file_list",
        request_class => "OpenAIAsync::Type::Request::FileList",
        result_class => "OpenAIAsync::Type::Results::FileList",
        decoder => 'optional_json', # this API input is OPTIONAL, if it's not present then we create a blank object to use.
    );
  }

  async method file_list($future_status, $queue, $ctx, $obj, $params);
  async method file_info($future_status, $queue, $ctx, $obj, $params);
  async method file_delete($future_status, $queue, $ctx, $obj, $params);
  async method file_upload($future_status, $queue, $ctx, $obj, $params);
  async method file_download($future_status, $queue, $ctx, $obj, $params);
}