#!/usr/bin/perl

use strict;

use HTTP::Daemon;
use LWP::UserAgent;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use IO::Compress::Gzip qw(gzip $GzipError);

my $ua = LWP::UserAgent->new();
my $d = HTTP::Daemon->new( 
  ReuseAddr => 1,
  LocalHost => "localhost", 
  LocalPort => 9999
) || die;
print "[Proxy URL:", $d->url, "]\n";

$SIG{'INT'} = sub {
  print "Closing the socket properly\n";
  $d->close();
  undef($d);
  exit();
};

$SIG{PIPE} = 'IGNORE';

fork(); fork(); fork(); 

while (my $c = $d->accept) {
  while (my $request = $c->get_request) {
    print $c->sockhost . ": " . $request->uri->as_string . "\n";

    $request->push_header( Via => "1.1 ". $c->sockhost );
    my $response = $ua->simple_request( $request );

    if($request->uri->as_string eq "http://www.legorafi.fr/jeu/js/core.js") {
      print "[+] extracting core.js\n";
      my $gzipdataref = $response->content_ref();
      my $dataref = new IO::Uncompress::Gunzip $gzipdataref or die "[!] gunzip failed: $GunzipError\n";
      print "[+] extraction successfull, modifying game\n";
      my $modifiedbuffer;
      my $line;
      while($line = $dataref->getline()){
        $line =~ s/saute=12;/saute=100;/ig;
        $modifiedbuffer = $modifiedbuffer.$line;
      }
      print "[+] done, recompression\n";
      my $newgzipdataref;
      gzip \$modifiedbuffer => \$newgzipdataref or die "gzip failed: $GzipError\n";
      $response->content_ref(\$newgzipdataref);
      print "[+] recompression successful\n";
    }

    $c->send_response( $response );
  }
  $c->close;
  undef($c);
}
