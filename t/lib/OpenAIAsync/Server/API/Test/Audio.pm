package OpenAIAsync::Server::API::Test::Audio;

use v5.36.0;
use Object::Pad;
use IO::Async::SSL; # We're not directly using it but I want to enforce that we pull it in when detecting dependencies, since openai itself is always https
use Future::AsyncAwait;
use IO::Async;

use OpenAIAsync::Types::Results;
use OpenAIAsync::Types::Requests;
use OpenAIAsync::Server::API::v1::Audio;


our $VERSION = '0.02';

# ABSTRACT: Async server for OpenAI style REST API for various AI systems (LLMs, Images, Video, etc.)

=pod

=head1 NAME

OpenAIAsync::Server::API::Audio - Basic audio api role, consumed to implement the OpenAI audio api.  Does not provide an implementation, you are expected to override them in your class

TODO document the subroles here, split up because TTS is much simpler to implement than the others and will be more valuable to support alone if someone chooses

=head1 SYNOPSIS
 
...

=cut


role OpenAIAsync::Server::API::Test::AudioTTS :strict(params) {
  apply OpenAIAsync::Server::API::v1::AudioTTS;
  async method audio_create_speech($obj, $http_req, $ctx) {...}
}

role OpenAIAsync::Server::API::Test::AudioSTT :strict(params) {
  apply OpenAIAsync::Server::API::v1::AudioSTT;
  async method audio_create_transcript($obj, $http_req, $ctx) {...}
}

role OpenAIAsync::Server::API::Test::AudioTranslate :strict(params) {
  apply OpenAIAsync::Server::API::v1::AudioTranslate;
  async method audio_create_translation($obj, $http_req, $ctx) {...}
}

role OpenAIAsync::Server::API::Test::Audio :strict(params) {
  apply OpenAIAsync::Server::API::Test::AudioTTS;
  apply OpenAIAsync::Server::API::Test::AudioSTT;
  apply OpenAIAsync::Server::API::Test::AudioTranslate;
}

1;