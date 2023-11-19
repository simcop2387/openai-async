use strict;
use warnings;

use Test2::V0;

use OpenAIAsync::Client;

lives {
  my $client = OpenAIAsync::Client->new();

  isa_ok($client, "OpenAIAsync::Client");
}, "basic client creation"; 

dies {
  my $client = OpenAIAsync::Client->new(bad_option_doesnt_exist => 1);

}, "Unknown options not working"; 

lives {
  my $client = OpenAIAsync::Client->new();

  isa_ok($client, "OpenAIAsync::Client");
}, "basic client creation"; 


done_testing();