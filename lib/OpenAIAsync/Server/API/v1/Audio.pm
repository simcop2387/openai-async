cpackage OpenAIAsync::Server::API::v1::Audio;

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

OpenAIAsync::Server::API::Audio - Basic audio api role, consumed to implement the OpenAI audio api.  Does not provide an implementation, you are expected to override them in your class

TODO document the subroles here, split up because TTS is much simpler to implement than the others and will be more valuable to support alone if someone chooses

=head1 SYNOPSIS
 
...

=cut

role OpenAIAsync::Server::API::v1::Audio :strict(params) {
  apply OpenAIAsync::Server::API::v1::AudioTTS;
  apply OpenAIAsync::Server::API::v1::AudioSTT;
  apply OpenAIAsync::Server::API::v1::AudioTranslate;
}

role OpenAIAsync::Server::API::v1::AudioTTS :strict(params) {
  ADJUST {
    $self->register_url(
        method => 'POST',
        url => qr{^/v1/audio/speech$}, 
        handle => async sub($req, $ctx, $obj, $params) {await $self->audio_create_speech($obj, $req, $ctx)},
        request_class => "OpenAIAsync::Type::Requests::CreateSpeech",
        result_class => "", # This gives back a file of audio data
    );
  }
 
  async method audio_create_speech($obj, $http_req, $ctx) {...}
}

role OpenAIAsync::Server::API::v1::AudioSTT :strict(params) {
  ADJUST {
    $self->register_url(
        method => 'POST',
        url => qr{^/v1/audio/transcription$}, 
        handle => async sub($req, $ctx, $obj, $params) {await $self->audio_create_transcript($obj, $req, $ctx)},
        request_class => "OpenAIAsync::Type::Requests::CreateTranscription",
        result_class => "", # This gives back a file, in the requested format
    );
  }
 
  async method audio_create_transcript($obj, $http_req, $ctx) {...}
}

role OpenAIAsync::Server::API::v1::AudioTranslate :strict(params) {
  ADJUST {
    $self->register_url(
        method => 'POST',
        url => qr{^/v1/$}, 
        handle => async sub($req, $ctx, $obj, $params) {await $self->audio_create_translation($obj, $req, $ctx)},
        request_class => "OpenAIAsync::Type::Requests::CreateTranslation",
        result_class => "", # This gives back a file, in the requested format
    );
  }
 
  async method audio_create_translation($obj, $http_req, $ctx) {...}
}