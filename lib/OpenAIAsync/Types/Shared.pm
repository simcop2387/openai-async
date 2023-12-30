package OpenAIAsync::Types::Shared;
use v5.36.0;
use Object::Pad;

use Object::PadX::Role::AutoMarshal;
use Object::PadX::Role::AutoJSON;
use Object::Pad::ClassAttr::Struct;
use OpenAIAsync::Types;

# TODO this is shared request and result?
# TODO Add a method here that given a file name will create a new object with things filled out
class OpenAIAsync::Types::Shared::FileObject :does(OpenAIAsync::Types::Requests::Base) :Struct {
  field $id :JSONStr = undef; # Only optional for uploads, but always comes back from the service.  TODO make a check
  field $bytes :JSONNum;
  field $created_at :JSONNum;
  field $filename :JSONStr;
  field $object :JSONStr = "file"; # Always a file, maybe enforce this in the future
  field $purpose :JSONStr; # fine-tune, fine-tune-results, assistants, or assistants_output
  field $status :JSONStr = undef; # DEPRECATED, current status of the file: uploaded, processed, or error
  field $status_detailts :JSONStr = undef; # DEPRECATED originally used for details of fine-tuning
}

1;