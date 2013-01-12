package dancer;
use Dancer ':syntax';
use Text::Markdown;
use Path::Class qw( file dir );
use Template;
use File::Find;
use Data::Dumper;

our $VERSION = '0.1';

sub parse_blog_entries {
    my $dir = shift;

    my @entries;
    find(
        sub {

            # we only care about blog entries
            return if !/\.md$/;

            # get a Path::Class::File for it
            my $file = file($File::Find::name);
            my $fh   = $file->openr;

            # parse a simple header using the kite secret operator
            chomp( my ( $title, $date, $tags ) =
                  ( ~~ <$fh>, ~~ <$fh>, ~~ <$fh> ) );
            $title =~ s/^[#\s]+//;
            $date  =~ s/^[#\s]+//;
            $tags  =~ s/^[#\s]+//;

            # update the structure will all relevant information
            my $source = substr( $File::Find::name, length($dir) );
            ( my $url = $source ) =~ s/\.md$/.html/;

            push @entries,
              {
                url    => '.' . $url,
                title  => $title,
                date   => $date,
                tags   => [ split /\s*,\s*/, $tags ],
                source => "$dir/$_",
              };
        },

        #setting( 'public' )
        $dir
    );

    return @entries;
}

get '/' => sub {

    #return "baf!";
    template 'about';
};

get '/public' => sub {
    template 'public';
};

get '/private' => sub {
    template 'private';
};

#
# blog
#

# blog main page
#
my $blog_dir = dir( setting('public'), 'blog' );
my $ext = 'md';

get '/blog' => sub {
    my %links;
    my @entries = parse_blog_entries($blog_dir);

    my @tags;
    for my $entry (@entries) {
        for my $tag ( @{ $entry->{tags} } ) {
            push @tags, $tag unless grep $tag eq $_, @tags;
        }
    }

    for my $entry (@entries) {
        $entry->{url} =~ s/(.*)/blog\/$1/;
    }

    set template => 'template_toolkit';
    template 'blog', { tags => \@tags, entries => \@entries };
};

# blog tags
#
get qr{/blog/(\w+)$} => sub {
    my ($tag) = splat;
    my @entries = parse_blog_entries($blog_dir);

    my @tagged_entries;
    for my $entry (@entries) {
        for my $entry_tag ( @{ $entry->{tags} } ) {
            if ( $entry_tag eq $tag ) {
                push @tagged_entries, $entry
                  unless grep $entry->{source} eq $_->{source}, @tagged_entries;
            }
        }
    }

    set template => 'template_toolkit';
    template 'blog_tags', { entries => \@tagged_entries };
};

# blog entries
#
my $m = Text::Markdown->new;

get qr{/blog/(.*)\.html} => sub {
    my ($file) = splat;
    my $text = file( $blog_dir, "$file.$ext" )->slurp;
    template 'blog_entry', { content => $m->markdown($text) };
};

true;
