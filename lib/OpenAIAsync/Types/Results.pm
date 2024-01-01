package OpenAIAsync::Types::Results;
use v5.36.0;
use Object::Pad;

use OpenAIAsync::Types;
use Object::PadX::Role::AutoMarshal;
use Object::PadX::Role::AutoJSON;
use Object::Pad::ClassAttr::Struct;

class OpenAIAsync::Types::Results::ToolCall :does(OpenAIAsync::Types::Base) :Struct {
  field $id :JSONStr = undef;
  field $type :JSONStr = undef; # always "function" right now, may get expanded in the future
  field $function :MarshalTo(OpenAIAsync::Types::Results::FunctionCall) = undef;
}

class OpenAIAsync::Types::Results::FunctionCall :does(OpenAIAsync::Types::Base) :Struct {
  field $arguments :JSONStr = undef; # TODO decode the json from this directly?
  field $name :JSONStr = undef;
}

class OpenAIAsync::Types::Results::ChatMessage :does(OpenAIAsync::Types::Base) :Struct {
  field $content :JSONStr;
  field $tool_calls :MarshalTo([OpenAIAsync::Types::Results::ToolCall]) = undef; # don't think my local server provides this
  field $role :JSONStr;
  field $function_call :MarshalTo(OpenAIAsync::Types::Results::FunctionCall) = undef; # Depcrecated, might still happen
}

class OpenAIAsync::Types::Results::ChatCompletionChoices :does(OpenAIAsync::Types::Base) :Struct {
  field $finish_reason :JSONStr;
  field $index :JSONNum;
  field $message :MarshalTo(OpenAIAsync::Types::Results::ChatMessage);
}

class OpenAIAsync::Types::Results::ChatCompletion :does(OpenAIAsync::Types::Base) :Struct {
  field $id :JSONStr;
  field $choices :MarshalTo([OpenAIAsync::Types::Results::ChatCompletionChoices]);
  field $created :JSONStr;
  field $model :JSONStr;
  field $system_fingerprint :JSONStr = undef; # My local system doesn't provide this
  field $usage :MarshalTo(OpenAIAsync::Types::Results::Usage);
  field $object :JSONStr;
}

class OpenAIAsync::Types::Results::ChunkDelta :does(OpenAIAsync::Types::Base) :Struct {
  field $content :JSONStr;
  field $function_call :MarshalTo(OpenAIAsync::Types::Results::FunctionCall) = undef;
  field $tool_cass :MarshalTo([OpenAIAsync::Types::Results::ToolCall]) = undef;
  field $role :JSONStr;
}

class OpenAIAsync::Types::Results::ChatCompletionChunkChoices :does(OpenAIAsync::Types::Base) :Struct {
  field $delta :MarshalTo(OpenAIAsync::Types::Results::ChunkDelta);
  field $finish_reason :JSONStr;
  field $index :JSONStr;
}

# This is part of the streaming API
class OpenAIAsync::Types::Results::ChatCompletionChunk :does(OpenAIAsync::Types::Base) :Struct {
  field $id :JSONStr;
  field $choices :MarshalTo(OpenAIAsync::Types::Results::ChatCompletionChunkChoices);
  field $created :JSONStr;
  field $model :JSONStr;
  field $system_fingerprint :JSONStr = undef;
  field $object :JSONStr;
}

class OpenAIAsync::Types::Results::Usage :does(OpenAIAsync::Types::Base) :Struct {
  field $total_tokens :JSONNum;
  field $prompt_tokens :JSONNum;
  field $completion_tokens :JSONNum = undef; # look at chat completions, is this the same
}

class OpenAIAsync::Types::Results::LogProbs :does(OpenAIAsync::Types::Base) :Struct {
  # TODO what's the representation here?
  field $text_offset = undef;
  field $token_logprobs = undef;
  field $tokens = undef;
  field $top_logprobs = undef;
}

class OpenAIAsync::Types::Results::CompletionChoices :does(OpenAIAsync::Types::Base) :Struct {
  field $text :JSONStr; 
  field $index :JSONNum;
  field $logprobs :MarshalTo([OpenAIAsync::Types::Results::LogProbs]) = undef; # TODO make nicer type?
  field $finish_reason :JSONStr = undef; # TODO enum? helper funcs for this class? ->is_finished?
}

class OpenAIAsync::Types::Results::Completion :does(OpenAIAsync::Types::Base) :Struct {
  field $id :JSONStr;
  field $choices :MarshalTo([OpenAIAsync::Types::Results::CompletionChoices]);
  field $created :JSONStr;
  field $model :JSONStr;
  field $system_fingerprint = undef; # my local implementation doesn't provide this, openai does it for tracking changes somehow
  field $usage :MarshalTo(OpenAIAsync::Types::Results::Usage);
  field $object :JSONStr;
}


class OpenAIAsync::Types::Results::Embedding :does(OpenAIAsync::Types::Base) :Struct {
  field $object :JSONStr;
  field $model :JSONStr;
  field $usage :MarshalTo(OpenAIAsync::Types::Results::Usage);
  field $data :MarshalTo([OpenAIAsync::Types::Results::EmbeddingData]);
}

class OpenAIAsync::Types::Results::EmbeddingData :does(OpenAIAsync::Types::Base) :Struct {
  field $index :JSONNum;
  field $embedding :JSONList(JSONNum);
  field $object :JSONStr;
}

class OpenAIAsync::Types::Results::ModelList :does(OpenAIAsync::Types::Base) :Struct {
  field $object :JSONStr = 'list';
  field $data :MarshalTo(OpenAIAsync::Types::Results::ModelInfo);
}

class OpenAIAsync::Types::Results::ModelInfo :does(OpenAIAsync::Types::Base) :Struct {
  field $created :JSONNum;
  field $id :JSONStr;
  field $object :JSONStr = "model";
  field $owned_by :JSONStr;
}

class OpenAIAsync::Types::Results::Moderation :does(OpenAIAsync::Types::Base) :Struct {
  field $id :JSONStr;
  field $model :JSONStr;
  field $results :MarshalTo([OpenAIAsync::Types::Results::ModerationResults]); # Not really sure why it's an array, the input doesn't allow multiple things to categorize
}

class OpenAIAsync::Types::Results::ModerationResults :does(OpenAIAsync::Types::Base) :Struct {
  field $flagged :JSONBool;
  field $categories :MarshalTo(OpenAIAsync::Types::Results::ModerationResultsCategories);
  field $category_scores :MarshalTo(OpenAIAsync::Types::Results::ModerationResultsCategoryScores);
}

class OpenAIAsync::Types::Results::ModerationResultsCategories :does(OpenAIAsync::Types::Base) :Struct {
  field $hate :JSONBool;
  field $hate_threatening :JSONBool :JSONKey(hate/threatening);
  field $harassment :JSONBool;
  field $harassment_threatening :JSONBool :JSONKey(harassment/threatening);
  field $self_harm :JSONBool :JSONKey(self-harm);
  field $self_harm_intent :JSONBool :JSONKey(self-harm/intent);
  field $self_harm_instructions :JSONBool :JSONKey(self-harm/instructions);
  field $sexual :JSONBool;
  field $sexual_minors :JSONBool :JSONKey(sexual/minors);
  field $violence :JSONBool;
  field $violence_graphic :JSONBool :JSONKey(violence/graphic);
}

class OpenAIAsync::Types::Results::ModerationResultsCategoryScores :does(OpenAIAsync::Types::Base) :Struct {
  field $hate :JSONNum;
  field $hate_threatening :JSONNum :JSONKey(hate/threatening);
  field $harassment :JSONNum;
  field $harassment_threatening :JSONNum :JSONKey(harassment/threatening);
  field $self_harm :JSONNum :JSONKey(self-harm);
  field $self_harm_intent :JSONNum :JSONKey(self-harm/intent);
  field $self_harm_instructions :JSONNum :JSONKey(self-harm/instructions);
  field $sexual :JSONNum;
  field $sexual_minors :JSONNum :JSONKey(sexual/minors);
  field $violence :JSONNum;
  field $violence_graphic :JSONNum :JSONKey(violence/graphic);
}

class OpenAIAsync::Types::Results::Image :does(OpenAIAsync::Types::Base) :Struct {
  field $b64_json :JSONStr = undef;
  field $url :JSONStr = undef;
  field $revised_prompt :JSONStr = undef;

  ADJUST {
    die "Missing required value one of b64_json or url" unless ($b64_json or $url);
  }
}
