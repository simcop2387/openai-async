package OpenAIAsync::Types::Requests;
use v5.36.0;
use Object::Pad;

use Object::PadX::Role::AutoMarshal;
use Object::PadX::Role::AutoJSON;
use Object::Pad::ClassAttr::Struct;
use OpenAIAsync::Types;

role OpenAIAsync::Types::Requests::Base :does(OpenAIAsync::Types::Base) :Struct {
  method _endpoint(); # How the client finds where to send the request
}

#### Base Request Types

class OpenAIAsync::Types::Requests::ChatCompletion :does(OpenAIAsync::Types::Requests::Base) :Struct {
  method _endpoint() {"/chat/completion"}
  field $messages :MarshalTo([OpenAIAsync::Types::Requests::ChatCompletion::Messages::Union]);
  field $model :JSONStr = "gpt-3.5-turbo";
  field $frequency_penalty :JSONNum = undefs;
  field $presence_penalty :JSONNum = undef;
  field $logit_bias = undef; # TODO wtf is this?
  field $max_tokens :JSONNum = undef;
  field $response_format :JSONStr :JSONExclude = undef; # I'm not supporting this this version yet

  field $seed :JSONNum = undef;
  field $stop = undef; # String, array or null, todo handle
  field $stream :JSONBool = undef; # TODO handle
  field $temperature :JSONNum = undef;
  field $top_p :JSONNum = undef;
  field $tools :JSONExclude = undef; # TODO handle this
  field $tool_choice :JSONExclude = undef; # TODO handle this

  field $function_call :JSONExclude = undef;
  field $functions :JSONExclude = undef;s
}

class OpenAIAsync::Types::Requests::Completion :does(OpenAIAsync::Types::Requests::Base) :Struct {
  method _endpoint() {"/completion"}
  
  field $model :JSONStr = "gpt-3.5-turbo"; # This is how 99% of everyone else seems to default this
  field $prompt :JSONStr;
  
  field $max_tokens :JSONNum = undef; # use the platform default usually
  field $temperature :JSONNum = undef;
  field $top_p :JSONNum = undef;
  field $seed :JSONNum  = undef;
  field $echo :JSONBool = undef; # true or false only
  field $suffix :JSONStr = undef;
  field $stop :JSONStr = undef; # array of stop tokens
  field $user :JSONStr = undef; # used for tracking purposes later

  field $frequency_penalty :JSONNum = undef;
  field $presence_penalty :JSONNum = undef;
  
  field $logit_bias = undef; # TODO make this work
  field $log_probs = undef; # TODO
  
  field $n :JSONNum = undef; # Danger will robinson! easy to cause $$$$$$$ costs
  field $best_of :JSONNum = undef;

  field $stream :JSONBool = undef; # TODO FALSE ALWAYS RIGHT NOW

  ADJUST {
    # Type assertions here
    die "Streaming unsupported" if $self->stream;
  }
}

class OpenAIAsync::Types::Requests::Embedding :does(OpenAIAsync::Types::Requests::Base) :Struct {
  method _endpoint() {...}
  field $input :JSONStr;
  field $model :JSONStr;
  field $encoding_format :JSONStr = undef;
  field $user :JSONStr = undef;
}

### Request Subtypes

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::Assistant::ToolCall :does(OpenAIAsync::Types::Base) :Struct {
  field $id :JSONStr;
  field $arguments :JSONStr;
  field $type :JSONStr;
  field $function :MarshalTo(OpenAIAsync::Types::Requests::ChatCompletion::Messages::Assistant::FunctionCall);
}

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::Assistant::FunctionCall :does(OpenAIAsync::Types::Base) {
  field $arguments :JSONStr;
  field $name :JSONStr;
}

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::User::Text :does(OpenAIAsync::Types::Base) :Struct {
  field $type :JSONStr;
  field $text :JSONStr;
}

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::User::ImageUrl :does(OpenAIAsync::Types::Base) :Struct {
  field $url :JSONStr;
  field $detail :JSONStr = undef;
}

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::User::Image :does(OpenAIAsync::Types::Base) :Struct {
  field $type :JSONStr;
  field $image_url :MarshalTo(OpenAIAsync::Types::Requests::ChatCompletion::Messages::User::ImageUrl);
}

# TODO, why have two of these? just shove it into the big one below

package 
    OpenAIAsync::Types::Requests::ChatCompletion::Messages::User::ContentUnion {
  # This guy does some additional checks to give us the right type here
  
  sub new {
    my $class = shift @_;
    my %input = @_;
  
    die "Missing type in creation" unless $input{type};

    if ($input{type} eq 'text') {
      return OpenAIAsync::Types::Requests::ChatCompletion::Messages::User::Text->new(%input);
    } elsif ($input{type} eq 'image') {
      return OpenAIAsync::Types::Requests::ChatCompletion::Messages::User::Image->new(%input);
    } else {
      die "Unsupported ChatCompletion User Message type: [".$input{type}."]";
    }
  }
};

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::User :does(OpenAIAsync::Types::Base) :Struct {
  # This particular type is more complicated than AutoMarshal can handle, so we need to
  # do this in a custom manner.
  field $role;
  field $name = undef;
  field $content;

  ADJUST {
    my $create_obj = sub {
      my $cont = shift;

      if (ref($cont) eq 'HASH') {
        # We've got a more detailed type here, create the union type here
        my $obj = OpenAIAsync::Types::Requests::ChatCompletion::Messages::User::ContentUnion->new(%$cont);
      } elsif (ref($cont) eq '') {
        return $cont; # Bare string/scalar is fine
      } else {
        die "Can't nest other types in \$content of a ChatCompletion user message: ".ref($cont);
      }
    };

    if (ref($content) eq 'ARRAY') {
      $content = [map {$create_obj->($_)} $content->@*];
    } else {
      $content = $create_obj->($content);
    }
  }
}

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::Assistant :does(OpenAIAsync::Types::Base) :Struct {
  field $role :JSONStr;
  field $content :JSONStr;
  field $name = undef;
  field $tool_calls :MarshalTo([OpenAIAsync::Types::Requests::ChatCompletion::Messages::Assistant::ToolCall]) = undef;
  field $function_call :MarshalTo(OpenAIAsync::Types::Requests::ChatCompletion::Messages::Assistant::FunctionCall) = undef;
}

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::Function :does(OpenAIAsync::Types::Base) :Struct {
  field $role :JSONStr;
  field $content :JSONStr;
  field $name :JSONStr;
}

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::Tool :does(OpenAIAsync::Types::Base) :Struct {
  field $role :JSONStr;
  field $content :JSONStr;
  field $tool_call_id :JSONStr;
}

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::System :does(OpenAIAsync::Types::Base) :Struct {
  field $role :JSONStr;
  field $name :JSONStr = undef;
  field $content :JSONStr;
}


package 
  OpenAIAsync::Types::Requests::ChatCompletion::Messages::Union {
  # This guy does some additional checks to give us the right type here
  
  sub new {
    my ($class, %input) = @_;
    die "Missing role in creation" unless $input{role};

    if ($input{role} eq 'system') {
      return OpenAIAsync::Types::Requests::ChatCompletion::Messages::System->new(%input);
    } elsif ($input{role} eq 'user') {
      return OpenAIAsync::Types::Requests::ChatCompletion::Messages::User->new(%input);
    } elsif ($input{role} eq 'tool') {
      return OpenAIAsync::Types::Requests::ChatCompletion::Messages::Tool->new(%input);
    } elsif ($input{role} eq 'function') {
      return OpenAIAsync::Types::Requests::ChatCompletion::Messages::Function->new(%input);
    } elsif ($input{role} eq 'assistant') {
      return OpenAIAsync::Types::Requests::ChatCompletion::Messages::Assistant->new(%input);
    } else {
      die "Unsupported ChatCompletion Message role: [".$input{role}."]";
    }
  }
};

1;  