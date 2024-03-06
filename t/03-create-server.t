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

my $res_fut = mk_req("/chat/completions", $chat_completion_input);

$loop->delay_future(after => 5)->get();

my $res = $res_fut->get();

my $content = $res->content;
is($content, '{"choices":[],"created":"0","id":"24601","model":"GumbyBrain-llm","object":"text_completion","system_fingerprint":"SHODAN node 12 of 16 tertiary adjunct of unimatrix 42","usage":{"completion_tokens":9,"prompt_tokens":6,"total_tokens":42}}', "check marshalling of data directly");




done_testing();
