package OpenAIAsync::Types;
use v5.36.0;
use Object::Pad;

use Object::PadX::Role::AutoMarshal;
use Object::PadX::Role::AutoJSON;
use Object::Pad::ClassAttr::Struct;

# Base role for all the types to simplify things later
role OpenAIAsync::Types::Base :Struct {
  apply Object::PadX::Role::AutoJSON;
  apply Object::PadX::Role::AutoMarshal;

  use JSON::MaybeXS qw//;

  our $_json = JSON::MaybeXS->new(utf8 => 1, convert_blessed => 1);

  method _encode() {
    return $_json->encode($self);
  }
}

# Keep the JSON role stuff here, I might use it to annotate encodings of some non-json fields? not sure
role OpenAIAsync::Types::BaseFormEncoding :Struct {
  apply Object::PadX::Role::AutoJSON;
  apply Object::PadX::Role::AutoMarshal;

  use WWW::Form::UrlEncoded;

  use Object::Pad::MOP::FieldAttr;
  use Object::Pad::MOP::Field;
  use Object::Pad::MOP::Class;

  my $_to_str = sub ($x) {
    return "".$x;
  };
 
  my $_to_num = sub ($x) {
    return 0+$x;
  };
 
  my $_to_bool = sub ($x) {
    return !!$x ? \1 : \0;
  };
 
  my $_to_list = sub ($ref, $type) {
    my $sub = $type eq 'JSONNum' ? $_to_num :
              $type eq 'JSONStr' ? $_to_str :
              $type eq 'JSONBool' ? $_to_bool :
                                    sub {die "Wrong type $type in json conversion"};
    return [map {$sub->($_)} $ref->@*]
  };

  method _as_hash() {
    my $class = __CLASS__;
    my $classmeta = Object::Pad::MOP::Class->for_class($class);
    my @metafields = $classmeta->fields;
 
    my %json_out = ();
 
    for my $metafield (@metafields) {
      my $field_name = $metafield->name;
      my $sigil = $metafield->sigil;
 
      my $has_exclude = $metafield->has_attribute("JSONExclude");
 
      next if $has_exclude;
 
      next if $sigil ne '$';  # Don't try to handle anything but scalars
 
      my $has_null = $metafield->has_attribute("JSONNull");
 
      my $value = $metafield->value($self);
      next unless (defined $value || $has_null);
 
      my $key = $field_name =~ s/^\$//r;
      $key = $metafield->get_attribute_value("JSONKey") if $metafield->has_attribute("JSONKey");
 
      if ($metafield->has_attribute('JSONBool')) {
        $value = $_to_bool->($value);
      } elsif ($metafield->has_attribute('JSONNum')) {
        # Force numification
        $value = $_to_num->($value);
      } elsif ($metafield->has_attribute('JSONList')) {
        my $type = $metafield->get_attribute_value('JSONList');
        $value = $_to_list->($value, $type);
      } else {
        # Force stringification
        $value = $_to_str->($value);
      }
 
      $json_out{$key} = $value;
    }
    return \%json_out;
  }


  method _encode() {
    my $hash = $self->_as_hash();
    my $string = WWW::Form::UrlEncoded::build_urlencoded($hash);
    return $string;
  }
}
