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

get '/hello/:name' => sub {
    return "Hello: " . params->{name};
};

#true;
dance;

