use strict;
use warnings;

use Test2::V0;

use OpenAIAsync::Server;
use Object::Pad;
use IO::Async::Loop;

use lib::relative './lib';

my $loop = IO::Async::Loop->new();

BEGIN {
  no warnings 'uninitialized';
  $ENV{OPENAI_API_KEY}="12345" unless $ENV{OPENAI_API_KEY}eq"12345";
}

class TestServer {
  inherit OpenAIAsync::Server;
  apply OpenAIAsync::Server::API::Test::ChatCompletion;
  apply OpenAIAsync::Server::API::Test::Audio;
  apply OpenAIAsync::Server::API::Test::Completions;
  apply OpenAIAsync::Server::API::Test::Embeddings;
  apply OpenAIAsync::Server::API::Test::File;
  apply OpenAIAsync::Server::API::Test::Image;
  apply OpenAIAsync::Server::API::Test::ModelList;
  apply OpenAIAsync::Server::API::Test::Moderations;
}

my $server = TestServer->new(listen => '127.0.0.1', port => 12345);

$loop->add($server);

$loop->delay_future(after => 120)->get();

done_testing();
