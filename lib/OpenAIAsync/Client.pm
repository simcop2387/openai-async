use v5.38.0;
use Object::Pad;
use IO::Async::SSL; # We're not directly using it but I want to enforce that we pull it in when detecting dependencies, since openai itself is always https
use Future::AsyncAwait;

use OpenAIAsync::Types::Results;
use OpenAIAsync::Types::Requests;

class OpenAIAsync::Client :repr(HASH) :isa(IO::Async::Notifier) {
  use JSON::MaybeXS qw//;
  use Net::Async::HTTP;
  use Feature::Compat::Try;
  use URI;

  field $_json = JSON::MaybeXS->new(utf8 => 1, convert_blessed => 1);

  field $_http_max_in_flight :param(http_max_in_flight) = 2;
  field $_http_max_redirects :param(http_max_redirects) = 3;
  field $_http_max_connections_per_host :param(http_max_connections_per_host) = 2;
  field $_http_timeout :param(http_timeout) = 120; # My personal server is kinda slow, use a generous default
  field $_http_stall_timeout :param(http_stall_timeout) = 600; # generous for my slow personal server
  field $_http_proxy_host :param(http_proxy_host) = undef;
  field $_http_proxy_port :param(http_proxy_port) = undef;
  field $_http_proxy_path :param(http_proxy_path) = undef;

  field $http;

  field $api_base :param(api_base) = $ENV{OPENAI_API_BASE} // "https://api.openai.com/v1";
  field $api_key :param(api_key) = $ENV{OPENAI_API_KEY};

  field $api_org_name :param(api_org_name) = undef;

  method configure(%params) {
    # We require them to go this way
    my %io_async_params = ($params{io_async_notifier_params} // {})->%*;
    IO::Async::Notifier::configure($self, );
  }

  method __make_http() {
    die "Missing API Key for OpenAI" unless $api_key;

    return Net::Async::HTTP->new(
      user_agent => "SNN OpenAI Client 1.0",
      +headers => {
        "Authorization" => "Bearer $api_key",
        "Content-Type" => "application/json",
        $api_org_name ? (
          'OpenAI-Organization' => $api_org_name,
        ) : ()
      },
      max_redirects => $_http_max_redirects,
      max_connections_per_host => $_http_max_connections_per_host,
      max_in_flight => $_http_max_in_flight,
      timeout => $_http_timeout,
      stall_timeout => $_http_stall_timeout,
      # TODO proxy stuff
    )
  }

  ADJUST {
    $http = $self->__make_http;

    $api_base =~ s|/$||; # trim an accidental final / since we will be putting it on the endpoints
  }

  async method _make_request($endpoint, $data) {
    my $json = $_json->encode($data);

    use Data::Dumper;
    print Dumper($json);

    my $url = URI->new($api_base . $endpoint );

    my $result = await $http->do_request(
      uri => $url,
      method => "POST",
      content => $json,
      content_type => 'application/json',
    );

    if ($result->is_success) {
      my $json = $result->decoded_content;
      my $out_data = $_json->decode($json);

      return $out_data;
    } else {
      die "Failure in talking to OpenAI service: ".$result->status_line.": ".$result->decoded_content;
    }
  }

   method _add_to_loop($loop) {
    $loop->add($http);
  }

  method _remove_from_loop($loop) {
    $loop->remove($http);
    $http = $self->__make_http; # overkill? want to make sure we have a clean one
  }

  # This is the legacy completion api
  async method completion($input) {

    if (ref($input) eq 'HASH') {
      $input = OpenAIAsync::Types::Requests::Completion->new($input->%*);
    } elsif (ref($input) eq 'OpenAIAsync::Types::Requests::Completion') {
      # dummy, nothing to do
    } else {
      die "Unsupported input type [".ref($input)."]";
    }

    print "Making request\n";

    my $data = await $self->_make_request("/completions", $input);

    my $type_result = OpenAIAsync::Types::Results::Completion->new($data->%*);

    return $type_result;
  }

  async method chat($prompt) {
    ...
  }

  async method embedding($input) {

  }

  async method image_generate($input) {
    ...
  }

  async method text_to_speech($text) {
    ...
  }

  async method speech_to_text($sound_data) {
    ...
  }

  async method vision($image, $prompt) {
    ...
  }
}