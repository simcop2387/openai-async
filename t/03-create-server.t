use strict;
use warnings;

use Test2::V0;

use OpenAIAsync::Server;
use Object::Pad;
use IO::Async::Loop;
use Future::AsyncAwait;
use JSON::MaybeXS;
use Net::Async::HTTP;

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

# Pick a random high port, TODO better scheme for this
my $port = int(2048+rand(20480));

my $server = TestServer->new(listen => '127.0.0.1', port => $port);
my $http_client = Net::Async::HTTP->new();
$loop->add($http_client);
$loop->add($server);

my $chat_completion_input = {
     "model" => "gpt-3.5-turbo",
     "messages" => [
        {"role" => "user", "content" => "Say this is a test!"}
      ],
     "temperature" => 0.7
};

sub mk_req($uri, $content) {
  my $content_json = encode_json($content);
  return $http_client->POST("http://127.0.0.1:$port/v1".$uri, $content_json, content_type => 'application/json');
}

my $res = await mk_req("/chat/completions", $chat_completion_input);

use Data::Dumper;
print Dumper($res);
#$loop->delay_future(after => 120)->get();

done_testing();
