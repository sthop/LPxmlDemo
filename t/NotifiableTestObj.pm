package NotifiableTestObj;

use Moose;
with 'Role::Notifiable';

__PACKAGE__->meta->make_immutable;
no Moose;
1;