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
   use File::Basename;
   use lib File::Spec->catdir($FindBin::Bin, '.', 'lib');


   use OMS 0.01;

   my $old_nls = $ENV{"NLS_LANG"};
   $ENV{"NLS_LANG"} = "american_america.ru8pc866";

   my $res = 0;
   my $fname;

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
   $res = $o->export_to_dbf("NCIVIDU") if $id eq "NCI_VID_U";
   #
   #
   $ENV{"NLS_LANG"} = $old_nls;
   #return send_file (
   #    $res,
   #    system_path => 1,
   #    content_type => 'appication/octet-stream'
   #) if $res ne "";
   $fname  = basename($res);
   return "<a href=\"/result/$fname\" class=\"btn btn-default\">".$fname."</a>" if $res ne "";
};

get '/result/:fname' => sub {
   return send_file (
       "/home/stas/OMS/out/".params->{fname},
       system_path => 1,
       content_type => 'appication/octet-stream'
   );
       # return "Hello: " . params->{fname};
};

#true;
dance;

