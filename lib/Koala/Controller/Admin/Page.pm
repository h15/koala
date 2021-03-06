package Koala::Controller::Admin::Page;
use Mojo::Base 'Koala::Controller::Admin::Base';
use Koala::Model::Page;
use Koala::Model::Comment;
use Koala::Model::Tag;
use Koala::Model::File;

has 'model_name' => 'page';

# Method: list
#   List of pages. $size is a SQL limit.
sub list {
  my $self = shift;
  my $page = int $self->param('page');
  my $page_list = eval { Koala::Model::Page::Manager
    ->get_pages(sort_by => '-id', limit => $self->size, offset => $self->size * ($page-1)) }
      or return $self->not_found;
  my $page_count = Koala::Model::Page::Manager->get_pages_count;
  $self->render('page/admin/list', page_list => $page_list, page_count => $page_count, limit => $self->size);
}

# Method: list_of_pages
#   List of single pages (not post).
sub list_of_pages {
  my $self = shift;
  my $page_list = eval { Koala::Model::Page::Manager->get_pages(
    query => [
      status => 40,
      priority => {ne => undef},
    ],
    sort_by => 'priority'
  ) };
  $self->render('page/admin/list_of_pages', list => $page_list);
}

# Method: show
#   Show one page for editing.
sub show {
  my $self = shift;
  my $page = Koala::Model::Page->new(id => int $self->param('id'))->load;
  $self->render('page/admin/form', item => $page,
    tag_list => Koala::Model::Tag::Manager->get_tags);
}

# Method: edit
#   Edit one page. Don't show form, just edit.
sub edit {
  my $self = shift;
  my $page = Koala::Model::Page->new(id => int $self->param('id'))->load;
  
  $page->$_($self->param($_)) for qw/url title legend status
    keywords description text author_id approver_id owner_id category_id/;
  $page->create_at($self->dt($self->param('create_at')));
  $page->modify_at($self->dt($self->param('modify_at')));
  
  if ($self->param('picture')->size) { # Load picture if exists
    my $file = Koala::Model::File->new->init_by_mojo_asset($self->param('picture'));
    $file->author_id($self->user->id);
    $file->save;
    $page->picture_id($file->id); 
  }
  
  $page->setTags(title => split /, /, $self->param('tags'));
  $page->save;
  
  $self->flash({message => 'Page edited', type => 'success'})
    ->redirect_to('admin_page_show', id => $page->id);
}

# Method: _dehydrate
#   Redefine if you wanna custom work with input.
sub _dehydrate {
  my ($self, $page) = @_;
  my ($model) = $self->_get_model();
  $page->$_($self->param($_)) for qw/url title legend status
    keywords description text author_id approver_id owner_id category_id/;
  $page->create_at($self->dt($self->param('create_at')));
  $page->modify_at($self->dt($self->param('modify_at')));
    
  if ($self->param('picture')->size) { # Load picture if exists
    my $file = Koala::Model::File->new->init_by_mojo_asset($self->param('picture'));
    $file->author_id($self->user->id);
    $file->save;
    $page->picture_id($file->id); 
  }
  
  $page->setTags(title => split /, /, $self->param('tags'));
  $page->save;
  $page->priority($page->id);
}

# Method: picture_crop
#   Crop picture.
sub picture_crop {
  my $self = shift;
  my $file = eval { Koala::Model::File->new(id => $self->param('id'))->load }
    or return $self->not_found_json;
  
  my $old_path = $file->path;
  $file->generate_path;
  $file = $file->copy_file($old_path, $file->path);
  
  $file->crop(
    x => $self->param('x'),
    y => $self->param('y'),
    w => $self->param('w'),
    h => $self->param('h'),
  );
  
  unlink($old_path);
  $file->save();
  
  return $self->render(json => {error => 0, img_src => $file->get_url});
}

sub up {
  my $self = shift;
  my $page = eval { Koala::Model::Page->new(id => $self->param('id'))->load } or return $self->not_found;
  my $prev = eval { Koala::Model::Page::Manager->get_pages(
    query => [
      status => 40,
      priority => {lt => $page->priority},
    ],
    limit => 1,
    order_by => ['priority']
  ) };
  return $self->redirect_to('admin_list_of_pages') unless @$prev;
  $prev = $prev->[0];
  
  my $tmp = $page->priority;
  $page->priority($prev->priority);
  $prev->priority(undef);
  $prev->save;
  $page->save;
  $prev->priority($tmp);
  $prev->save;
  
  return $self->redirect_to('admin_list_of_pages');
}

sub down {
  my $self = shift;
  my $page = eval { Koala::Model::Page->new(id => $self->param('id'))->load } or return $self->not_found;
  my $prev = eval { Koala::Model::Page::Manager->get_pages(
    query => [
      status => 40,
      priority => {gt => $page->priority},
    ],
    limit => 1,
    order_by => ['priority']
  ) };
  return $self->redirect_to('admin_list_of_pages') unless @$prev;
  $prev = $prev->[0];
  
  my $tmp = $page->priority;
  $page->priority($prev->priority);
  $prev->priority(undef);
  $prev->save;
  $page->save;
  $prev->priority($tmp);
  $prev->save;
  
  return $self->redirect_to('admin_list_of_pages');
}

1;

__END__

=pod

=head1 NAME

Koala::Controller::Admin::Page - admin interface for pages.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013, Georgy Bazhukov <georgy.bazhukov@gmail.com> aka bugov <gosha@bugov.net>.

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
