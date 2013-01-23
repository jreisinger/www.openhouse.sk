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
            chomp( my ( $title, $tags ) = ( ~~ <$fh>, ~~ <$fh> ) );
            $title =~ s/^[#\s]+//;
            $tags =~ s/^[#\s]+//;

            # update the structure will all relevant information
            my $source = substr( $File::Find::name, length($dir) );
            ( my $url = $source ) =~ s/\.md$/.html/;

            push @entries,
              {
                url    => '.' . $url,
                title  => $title,
                tags   => [ split /\s*,\s*/, $tags ],
                source => "$dir/$_",
              };
        },

        #setting( 'public' )
        $dir
    );

    return sort { "\L$a->{title}" cmp "\L$b->{title}" } @entries;
}

sub get_tags {
    my $blog_dir = shift;

    my @entries = parse_blog_entries($blog_dir);
    my @tags;
    for my $entry (@entries) {
        for my $tag ( @{ $entry->{tags} } ) {
            push @tags, $tag unless grep $tag eq $_, @tags;
        }
    }

    return sort @tags;
}

sub get_rand_lines {

    # Return $n random lines
    my $file = shift;
    my $n = shift // 1;    # defaults to 1

    open my $fh, "<:encoding(UTF-8)", $file or die "$file: $!\n";
    chomp( my @lines = <$fh> );

    my @rand_lines;
    while ( @rand_lines < $n ) {
        my $rand_line = @lines[ rand @lines ];
        push @rand_lines, $rand_line;
    }

    close $fh;

    return @rand_lines;
}

# # #

get '/' => sub {
    template 'about';
};

get '/public' => sub {
    template 'public';
};

get '/private' => sub {
    template 'private';
};

# blog main page
#
my $blog_dir = dir( setting('public'), 'blog' );
my $ext = 'md';

get '/blog' => sub {
    my %links;
    my @entries = parse_blog_entries($blog_dir);

    my @tags = get_tags($blog_dir);

    my ($quote) = get_rand_lines($blog_dir . "/" . "quotes.txt");

    template 'blog', { tags => \@tags, quote => $quote, entries => \@entries };
};

# blog tags
#
get qr{/blog/(\w+)$} => sub {
    my ($tag) = splat;

    my @entries = parse_blog_entries($blog_dir);

    my @tags = get_tags($blog_dir);

    my @tagged_entries;
    for my $entry (@entries) {
        for my $entry_tag ( @{ $entry->{tags} } ) {
            if ( $entry_tag eq $tag ) {
                push @tagged_entries, $entry
                  unless grep $entry->{source} eq $_->{source}, @tagged_entries;
            }
        }
    }

    template 'blog_tags',
      {
        tag     => $tag,
        tags    => \@tags,
        entries => \@tagged_entries
      };
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
