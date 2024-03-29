package OpenAIAsync::Types::Requests;
use v5.36.0;
use Object::Pad;

use Object::PadX::Role::AutoMarshal;
use Object::PadX::Role::AutoJSON;
use Object::Pad::ClassAttr::Struct;
use OpenAIAsync::Types;
use OpenAIAsync::Types::Shared;

role OpenAIAsync::Types::Requests::Base :Struct {
  apply OpenAIAsync::Types::Base;
  method _endpoint(); # How the client finds where to send the request
  method decoder() {"json"}
  method encoder() {"json"}
}

role OpenAIAsync::Types::Requests::BaseFormEncoding :Struct {
  apply OpenAIAsync::Types::BaseFormEncoding;
  method _endpoint(); # How the client finds where to send the request
  method decoder() {"www-form-urlencoded"}
  method encoder() {"www-form-urlencoded"}
}

#### Base Request Types

class OpenAIAsync::Types::Requests::ChatCompletion :Struct {
  apply OpenAIAsync::Types::Requests::Base;
  method _endpoint() {"/chat/completions"}
  
  field $messages :MarshalTo([OpenAIAsync::Types::Requests::ChatCompletion::Messages::Union]);
  field $model :JSONStr = "gpt-3.5-turbo";
  field $frequency_penalty :JSONNum = undef;
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
  field $functions :JSONExclude = undef;
}

class OpenAIAsync::Types::Requests::Completion :Struct {
  apply OpenAIAsync::Types::Requests::Base;

  method _endpoint() {"/completions"}
  
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

class OpenAIAsync::Types::Requests::Embedding :Struct {
  apply OpenAIAsync::Types::Requests::Base;
  method _endpoint() {"/embeddings"}
  field $input :JSONStr;
  field $model :JSONStr;
  field $encoding_format :JSONStr = undef;
  field $user :JSONStr = undef;
}

### Request Subtypes

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::Assistant::ToolCall :Struct {
  apply OpenAIAsync::Types::Base;
  field $id :JSONStr;
  field $arguments :JSONStr;
  field $type :JSONStr;
  field $function :MarshalTo(OpenAIAsync::Types::Requests::ChatCompletion::Messages::Assistant::FunctionCall);
}

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::Assistant::FunctionCall :Struct {
  apply OpenAIAsync::Types::Base;
  field $arguments :JSONStr;
  field $name :JSONStr;
}

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::User::Text :Struct {
  apply OpenAIAsync::Types::Base;
  field $type :JSONStr;
  field $text :JSONStr;
}

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::User::ImageUrl :Struct {
  apply OpenAIAsync::Types::Base;
  field $url :JSONStr;
  field $detail :JSONStr = undef;
}

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::User::Image :Struct {
  apply OpenAIAsync::Types::Base;
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
    } elsif ($input{type} eq 'image_url') {
      return OpenAIAsync::Types::Requests::ChatCompletion::Messages::User::Image->new(%input);
    } else {
      die "Unsupported ChatCompletion User Message type: [".$input{type}."]";
    }
  }
};

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::User :Struct {
  apply OpenAIAsync::Types::Base;
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
      # TODO check that this is acutally doing the right thing.  I think it might not be for user messages that are just text
      $content = $create_obj->($content);
    }
  }
}

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::Assistant :Struct {
  apply OpenAIAsync::Types::Base;
  field $role :JSONStr;
  field $content :JSONStr;
  field $name = undef;
  field $tool_calls :MarshalTo([OpenAIAsync::Types::Requests::ChatCompletion::Messages::Assistant::ToolCall]) = undef;
  field $function_call :MarshalTo(OpenAIAsync::Types::Requests::ChatCompletion::Messages::Assistant::FunctionCall) = undef;
}

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::Function :Struct {
  apply OpenAIAsync::Types::Base;
  field $role :JSONStr;
  field $content :JSONStr;
  field $name :JSONStr;
}

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::Tool :Struct {
  apply OpenAIAsync::Types::Base;
  field $role :JSONStr;
  field $content :JSONStr;
  field $tool_call_id :JSONStr;
}

class OpenAIAsync::Types::Requests::ChatCompletion::Messages::System :Struct {
  apply OpenAIAsync::Types::Base;
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

class OpenAIAsync::Types::Requests::FileUpload :Struct {
  apply OpenAIAsync::Types::Requests::Base;
  method _endpoint() {"/files"}

  field $file :MarshalTo(OpenAIAsync::Types::Shared::FileObject);
  field $purpose :JSONStr; # fine-tune and assistants for the types, TODO check format/type of file
}


class OpenAIAsync::Types::Requests::FileList :Struct {
  apply OpenAIAsync::Types::Requests::Base;
  method _endpoint() {"/files"}

  field $purpose :JSONStr = undef; # fine-tune and assistants for the types, optional, used for filtering
}

class OpenAIAsync::Types::Requests::FileInfo :Struct {
  apply OpenAIAsync::Types::Requests::Base;
  method _endpoint() {"/files/".$self->file_id}

  field $file_id :JSONStr; # id of the file to retrieve
}

class OpenAIAsync::Types::Requests::FileDelete :Struct {
  apply OpenAIAsync::Types::Requests::Base;
  method _endpoint() {"/files/".$self->file_id}

  field $file_id :JSONStr; # id of the file to retrieve
}

class OpenAIAsync::Types::Requests::FileContent :Struct {
  apply OpenAIAsync::Types::Requests::Base;
  method _endpoint() {"/files/".$self->file_id.'/content'}

  field $file_id :JSONStr; # id of the file to retrieve
}

class OpenAIAsync::Types::Requests::CreateSpeech :Struct {
  apply OpenAIAsync::Types::Requests::Base;
  method _endpoint() {"/audio/speech"}

  field $model :JSONStr = 'tts-1'; # default to cheapest model for simpler requests
  field $input :JSONStr; # TODO max 4k chars?
  field $voice :JSONStr; # TODO default to alloy?
  field $response_format :JSONStr = undef; # mp3, opus, aac, or flac
  field $speed :JSONNum = undef; # default 1.0, range 0.25 to 4.0
}

class OpenAIAsync::Types::Requests::CreateTranscript :Struct {
  apply OpenAIAsync::Types::Requests::BaseFormEncoding;
  method _endpoint() {"/audio/transcript"}

  field $file;
  field $model;
  field $language = undef; # What language to use, ISO-639-1 format
  field $prompt = undef; # Text to guide the model's style or continue a previous audio segment
  field $response_format = undef; # json, text, srt, verbose_json or vtt
  field $temperature = undef; # number, between 0 and 1.  higher values with make the ouput more random but lower values will make it more deterministic.
}

# ED: Why do they only support translating audio to english? seems really limited and I feel like this API will get
# updated or replaced fairly soon
class OpenAIAsync::Types::Requests::CreateTranslations :Struct {
  apply OpenAIAsync::Types::Requests::BaseFormEncoding;

  method _endpoint() {"/audio/translations"}

  field $file;
  field $model;
  field $prompt = undef; # Text to guide the model's style or continue a previous audio segment
  field $response_format = undef; # json, text, srt, verbose_json or vtt
  field $temperature = undef; # number, between 0 and 1.  higher values with make the ouput more random but lower values will make it more deterministic.
}

class OpenAIAsync::Types::Requests::Moderations :Struct {
  apply OpenAIAsync::Types::Requests::Base;
  method _endpoint() {"/moderations"}

  field $input :JSONStr;
  field $model :JSONStr = undef;
}

class OpenAIAsync::Types::Requests::GenerateImage :Struct {
  apply OpenAIAsync::Types::Requests::Base;
  method _endpoint() {"/images/generations"}

  field $prompt :JSONStr;
  field $model :JSONStr = undef;
  field $n :JSONNum = undef; # how many to generate
  field $quality :JSONStr = undef; # defaults to "standard", can also be "hd"
  field $response_format :JSONStr = undef; # url, or b64_json
  field $size :JSONStr = undef; # defaults to 1024x1024
  field $style :JSONStr = undef; # vivid or natural, defaults to vivid
  field $user :JSONStr = undef;
}

class OpenAIAsync::Types::Requests::CreateImageEdit :Struct {
  apply OpenAIAsync::Types::Requests::BaseFormEncoding;
  method _endpoint() {"/images/edits"}

  field $image; # Image file data, TODO document?
  field $mask = undef; # Image file data for mask, TODO document
  field $prompt :JSONStr;
  field $model :JSONStr = undef;
  field $n :JSONNum = undef; # how many to generate
  field $response_format :JSONStr = undef; # url, or b64_json
  field $size :JSONStr = undef; # defaults to 1024x1024
  field $user :JSONStr = undef;
}

class OpenAIAsync::Types::Requests::CreateImageVariation :Struct {
  apply OpenAIAsync::Types::Requests::BaseFormEncoding;
  method _endpoint() {"/images/variations"}

  field $image; # Image file data, TODO document?
  field $model :JSONStr = undef;
  field $n :JSONNum = undef; # how many to generate
  field $response_format :JSONStr = undef; # url, or b64_json
  field $size :JSONStr = undef; # defaults to 1024x1024
  field $user :JSONStr = undef;
}

1;