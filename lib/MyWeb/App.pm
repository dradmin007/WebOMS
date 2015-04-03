package MyWeb::App;
use Dancer2;

our $VERSION = '0.1';

get '/' => sub {
    header('Access-Control-Allow-Credentials'	=> 'true');
    template 'index';
};

get '/generator' => sub {
  header('Access-Control-Allow-Credentials'	=> 'true');
  template 'generator';
};

post '/oms' => sub {
   use strict;
   use warnings;

   use FindBin;
   use File::Spec;
   use lib File::Spec->catdir($FindBin::Bin, '.', 'lib');


   use OMS 0.01;

   my $old_nls = $ENV{"NLS_LANG"};
   $ENV{"NLS_LANG"} = "american_america.ru8pc866";

   my $res = 0;

   my $id = params->{id};
   my ($month, $year) = split '-',params->{int_date};
   #
   my $o = OMS->new( {'year' => $year, 'month' => $month} );
   $res = $o->export_to_dbf("STREETS") if $id eq "STREETS";
   $res = $o->export_to_dbf("SEGMENTS") if $id eq "SEGMENTS";
   $res = $o->export_to_dbf("RES_SP") if $id eq "RES_SP";
   $res = $o->export_to_dbf("STASMP") if $id eq "STASMP";
   $res = $o->export_to_dbf("BRSP") if $id eq "BRSP";
   $res = $o->export_to_dbf("SSP4708") if $id eq "SSP4708";
   #
   #
   $ENV{"NLS_LANG"} = $old_nls;
   return "Done!" if $res == 1;
};

get '/hello/:name' => sub {
    return "Hello: " . params->{name};
};

#true;
dance;

