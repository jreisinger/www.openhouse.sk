package dancer;
use Dancer ':syntax';
use Text::Markdown;
use Path::Class qw( file );
use Template;

our $VERSION = '0.1';

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
get '/blog' => sub {
    my %links;
    for my $file ( glob "public/*.txt" ) {
        my ($name) = $file =~ /\/(\w+)\.txt$/;
        my $link = $name;
        $link =~ s/^(.*)$/blog\/$1.html/;
        $links{$name} = $link;
    }
    set template => 'template_toolkit';
    template 'blog1', { links => \%links };
};

#
# blog entries
#
my $m = Text::Markdown->new;

get qr{/blog/(.*)\.html} => sub {
    my ($file) = splat;
    my $text = file( setting('public') => "$file.txt")->slurp;
    template 'blog', { content => $m->markdown($text) };
};

true;
