use strict;
use warnings;

use Test2::V0;

use OpenAIAsync::Client;

skip_all("Needs disclaimer to run") unless $ENV{I_PROMISE_NOT_TO_SUE_FOR_EXCESSIVE_COSTS} eq "Signed, ".getlogin();

skip_all("No api base defined")  unless $ENV{OPENAI_API_BASE};
skip_all("No API key defined") unless $ENV{OPENAI_API_KEY};

exit() unless ($ENV{OPENAI_API_KEY} and $ENV{OPENAI_API_BASE} and $ENV{I_PROMISE_NOT_TO_SUE_FOR_EXCESSIVE_COSTS} eq "Signed, ".getlogin());

use IO::Async::Loop;

my $loop = IO::Async::Loop->new();

my $client;
ok(lives {
  $client = OpenAIAsync::Client->new();

  isa_ok($client, "OpenAIAsync::Client");
}, "basic client creation"); 

ok(lives {$loop->add($client);}, "Adding to loop");

my $output_future = $client->chat({
    model => "gpt-3.5-turbo",
    messages => [
      {
        role => "system",
        content => "You are a helpful assistant that tells fanciful stories"
      },
      {
        role => "user",
        content => "Hello!"
      }
    ],



  max_tokens => 1024, 
});

use Data::Dumper;
print Dumper($output_future->get());

done_testing();