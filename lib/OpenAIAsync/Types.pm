package OpenAIAsync::Types;
use v5.36.0;
use Object::Pad;

use Object::PadX::Role::AutoMarshal;
use Object::PadX::Role::AutoJSON;
use Object::Pad::ClassAttr::Struct;

# Base role for all the types to simplify things later
role OpenAIAsync::Types::Base :does(Object::PadX::Role::AutoJSON) :does(Object::PadX::Role::AutoMarshal) :Struct {
}
