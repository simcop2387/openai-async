package OpenAIAsync::Server::Stream;

use v5.36;
use Object::Pad;

class OpenAIAsync::Server::Stream {
  use Future::Queue;

  # TODO what to do for non-io async setups, long term
  field $io_stream :param;
  
  async method send_headers() {

  }

  async method send_event($event_data) {
    
  }

  async method finish() {
    
  }
}