package OpenAIAsync::Types::Results;
use v5.38.0;
use Object::Pad;

use OpenAIAsync::Types;
use Object::PadX::Role::AutoMarshal;
use Object::PadX::Role::AutoJSON;
use Object::Pad::ClassAttr::Struct;

class OpenAIAsync::Types::Results::ToolCall :does(OpenAIAsync::Types::Base) {
  field $id;
  field $type; # always "function" right now, may get expanded in the future
  field $function :MarshalTo(OpenAIAsync::Types::Results::FunctionCall);
}

class OpenAIAsync::Types::Results::FunctionCall :does(OpenAIAsync::Types::Base) {
  field $arguments; # TODO decode the json from this directly?
  field $name;
}

class OpenAIAsync::Types::Results::ChatMessage :does(OpenAIAsync::Types::Base) {
  field $content;
  field $tool_calls :MarshalTo([OpenAIAsync::Types::Results::ToolCall]) = undef; # don't think my local server provides this
  field $role;
  field $function_call :MarshalTo(OpenAIAsync::Types::Results::FunctionCall) = undef; # Depcrecated, might still happen
}

class OpenAIAsync::Types::Results::ChatCompletionChoices :does(OpenAIAsync::Types::Base) {
  field $finish_reason;
  field $index;
  field $message :MarshalTo(OpenAIAsync::Types::Results::ChatMessage);
}

class OpenAIAsync::Types::Results::ChatCompletion :does(OpenAIAsync::Types::Base) {
  field $id;
  field $choices :MarshalTo([OpenAIAsync::Types::Results::ChatCompletionChoices]);
  field $created;
  field $model;
  field $system_fingerprint = undef; # My local system doesn't provide this
  field $usage :MarshalTo(OpenAIAsync::Types::Results::Usage);
  field $object;
}

class OpenAIAsync::Types::Results::ChunkDelta :does(OpenAIAsync::Types::Base) {
  field $content;
  field $function_call :MarshalTo(OpenAIAsync::Types::Results::FunctionCall);
  field $tool_cass :MarshalTo([OpenAIAsync::Types::Results::ToolCall]);
  field $role;
}

class OpenAIAsync::Types::Results::ChatCompletionChunkChoices :does(OpenAIAsync::Types::Base) {
  field $delta :MarshalTo(OpenAIAsync::Types::Results::ChunkDelta);
  field $finish_reason;
  field $index;
}

# This is part of the streaming API
class OpenAIAsync::Types::Results::ChatCompletionChunk :does(OpenAIAsync::Types::Base) {
  field $id;
  field $choices :MarshalTo(OpenAIAsync::Types::Results::ChatCompletionChunkChoices);
  field $created;
  field $model;
  field $system_fingerprint = undef;
  field $object;
}

class OpenAIAsync::Types::Results::Usage :does(OpenAIAsync::Types::Base) {
  field $total_tokens;
  field $prompt_tokens;
  field $completion_tokens; # look at chat completions, is this the same
}

class OpenAIAsync::Types::Results::LogProbs :does(OpenAIAsync::Types::Base) {
  field $text_offset = undef;
  field $token_logprobs = undef;
  field $tokens = undef;
  field $top_logprobs = undef;
}

class OpenAIAsync::Types::Results::CompletionChoices :does(AutoMarshal) :Struct {
  field $text; 
  field $index;
  field $logprobs :MarshalTo(OpenAIAsync::Types::Results::LogProbs) = undef; # TODO make nicer type?
  field $finish_reason = undef; # TODO enum? helper funcs for this class? ->is_finished?
}

class OpenAIAsync::Types::Results::Completion :does(AutoMarshal) :Struct {
  field $id;
  field $choices :MarshalTo([OpenAIAsync::Types::Results::CompletionChoices]);
  field $created;
  field $model;
  field $system_fingerprint = undef; # my local implementation doesn't provide this, openai does it for tracking changes somehow
  field $usage :MarshalTo(OpenAIAsync::Types::Results::Usage);
  field $object;
}

class OpenAIAsync::Types::Results::Embedding :does(AutoMarshal) :Struct {
  field $index;
  field $embedding;
  field $object;
}