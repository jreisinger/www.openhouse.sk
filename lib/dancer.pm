package dancer;
use Dancer ':syntax';
use Text::Markdown;
use Path::Class qw( file dir );
use Template;
use File::Find;
use Data::Dumper;
use Dancer::Plugin::SiteMap;
use 5.010;

our $VERSION = '0.1';

sub parse_blog_entries {

    # Return AoH, where
    #   A -- sorted list of blog posts
    #   H -- various info on the blog post

    my $dir = shift;
    my $sort = shift // "by_title";    # defaults to sorting by title

    my @entries;
    find(
        sub {

            # we only care about blog entries
            return if !/\.md$/;

            # get a Path::Class::File for it
            my $file = file($File::Find::name);

            my $mtime       = ( stat($file) )[9];    # for sorting
            my $mtime_human = localtime $mtime;

            my $fh = $file->openr;

            # parse a simple header using the kite secret operator
            chomp( my ( $title, $tags ) = ( ~~ <$fh>, ~~ <$fh> ) );
            $title =~ s/^[#\s]+//;
            $tags =~ s/^[#\s]+//;

            # update the structure will all relevant information
            my $source = substr( $File::Find::name, length($dir) );
            ( my $url = $source ) =~ s/\.md$/.html/;

            push @entries,
              {
                url         => '.' . $url,
                title       => $title,
                tags        => [ split /\s*,\s*/, $tags ],
                source      => "$dir/$_",
                mtime       => $mtime,
                mtime_human => $mtime_human,
              };
        },

        $dir
    );

    if ( $sort eq "by_title" ) {
        return sort { "\L$a->{title}" cmp "\L$b->{title}" } @entries;
    } else {
        return sort {
            $b->{mtime} <=> $a->{mtime} or "\L$a->{title}" cmp "\L$b->{title}"
        } @entries;
    }
}

sub get_tags {

    # Return sorted list of tags (blog posts categories)

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
        next if $rand_line =~ /^\s*$/;    # skip empty lines
        push @rand_lines, $rand_line;
    }

    close $fh;

    return @rand_lines;
}

my $blog_dir = dir( setting('public'), 'blog' );
my $ext = 'md';

get '/' => sub {
    template 'about', { title => "About" };
};

get '/private' => sub {
    template 'private', { title => "Private Resources" };
};

get '/jozef' => sub {
    template 'jozef', { title => "Jozef" };
};

# doneThis
#

get qr{/doneThis\.html} => sub {
    my $ext = "markdown"; # to distinguish from blog posts which have .md
    my $text = file( $blog_dir, "jozef.$ext" )->slurp;

    # Get title
    my $title = (split "\n", $text)[0]; # first line is the title
    $title =~ s/^#\s+//;

    # Inject quote after title
    my ($quote) = get_rand_lines( $blog_dir . "/" . "quotes.txt" );
    my $warn = "(Some quotes are in Slovak or Italian. If you don't understand, don't worry, just hit F5. :)";
    $text =~ s/^(#\s*.*)/$1\n\n$warn\n\n<code>$quote<\/code>\n/;

    my $m = Text::Markdown->new;
    template 'blog_entry', { title => $title, content => $m->markdown($text) };
};

# blog main page
#

get '/blog' => sub {
    my %links;
    my @entries = parse_blog_entries( $blog_dir, "by_mtime" );
    #@entries = @entries[0 .. 9]; # get only first ten posts

    my @tags = get_tags($blog_dir);

    template 'blog', { title => "All Blog Posts", tags => \@tags, entries => \@entries };
};

# categories (tags)
#
get qr{/blog/(\w+)$} => sub {
    my ($tag) = splat;

    my @entries = parse_blog_entries($blog_dir, "by_mtime");
    my @tags    = get_tags($blog_dir);

    # Push entries (posts) under their tags
    my @tagged_entries;
    for my $entry (@entries) {
        for my $entry_tag ( @{ $entry->{tags} } ) {
            if ( $entry_tag eq $tag ) {
                push @tagged_entries, $entry
                  unless grep $entry->{source} eq $_->{source},
                  @tagged_entries;
            }
        }
    }

    # Set nice web page title
    my $title;
    given ($tag) {
        when ("various") { $title = "Various Blog Posts"; }
        default          { $title = "$tag Related Blog Posts"; }
    }

    template 'blog_tags',
      {
        title   => $title,
        tags    => \@tags,
        entries => \@tagged_entries
      };
};

# blog entries
#

# Redirect requests to "old" blog posts
get '/blog/*/*' => sub {
    my $blog_post = (splat)[1];
    forward "/blog/" . $blog_post;
};

get qr{/blog/(.*)\.html} => sub {
    my ($file) = splat;
    my $text = file( $blog_dir, "$file.$ext" )->slurp;

    # Post title and tags
    my ($title, $tags) = (split "\n", $text)[0,1]; # first line is the title, second line are tags
    $title =~ s/^#\s+//;

    # Changing '###### tag1, tag2' to 'Tags: [tag1](blog/tag1) [tag2](blog/tag2)'
    $tags =~ s/^#+//;
    $tags =~ s/\s+//g;
    my @tags = split ",", $tags;
    s|(\w+)|[$1](/blog/$1)| for @tags;
    $text =~ s|^#{4,}.*$|Tags: @tags|m; # There should be 6 pounds ('#') but you never know :)

    my $m = Text::Markdown->new;
    template 'blog_entry', { title => $title, content => $m->markdown($text) };
};

true;
