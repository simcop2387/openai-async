package OpenAIAsync::Client::Stream;

use v5.36;
use Object::Pad;

class OpenAIAsync::Client::Stream {
  use Future::Queue;
  use Future::AsyncAwait;

  field $queue = Future::Queue->new();
  field $io_stream :param;

  ADJUST {
  }

  # Put an event into the queue once it's come in from $io_stream
  method _send_event() {

  }

  async method next_event() {

  }
}