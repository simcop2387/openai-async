package OpenAIAsync::Server::API::Test::File;

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

role OpenAIAsync::Server::API::Test::File :strict(params) {
  apply OpenAIAsync::Server::API::v1::File;

  async method file_list($future_status, $queue, $ctx, $obj, $params) {...}
  async method file_info($future_status, $queue, $ctx, $obj, $params) {...}
  async method file_delete($future_status, $queue, $ctx, $obj, $params) {...}
  async method file_upload($future_status, $queue, $ctx, $obj, $params) {...}
  async method file_download($future_status, $queue, $ctx, $obj, $params) {...}
}