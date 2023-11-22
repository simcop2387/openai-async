use strict;
use warnings;

use Test2::V0;

use OpenAIAsync::Client;

skip_all("Needs disclaimer to run") unless $ENV{I_PROMISE_NOT_TO_SUE_FOR_EXCESSIVE_COSTS} eq "Signed, ".getlogin();

skip_all("No api base defined")  unless $ENV{OPENAI_API_BASE};
skip_all("No API key defined") unless $ENV{OPENAI_API_KEY};

exit() unless ($ENV{OPENAI_API_KEY} and $ENV{OPENAI_API_BASE} and $ENV{I_PROMISE_NOT_TO_SUE_FOR_EXCESSIVE_COSTS} eq "Signed, ".getlogin());

ok(lives {
  my $client = OpenAIAsync::Client->new();

  isa_ok($client, "OpenAIAsync::Client");
}, "basic client creation"); 

my $exp = dies {
  my $client = OpenAIAsync::Client->new(bad_option_doesnt_exist => 1);
}; 

ok($exp, "Unknown option kills creation");

like($exp, qr/Unrecognised parameters for OpenAIAsync::Client constructor: 'bad_option_doesnt_exist' at/, "exception text for unknonwn option");

ok lives {
  my $client = OpenAIAsync::Client->new(http_other_options => {});

  isa_ok($client, "OpenAIAsync::Client");
}, "set http options"; 

ok lives {
  my $client = OpenAIAsync::Client->new(io_async_notifier_params=>{});

  isa_ok($client, "OpenAIAsync::Client");
}, "Can give io async notifier options"; 



done_testing();