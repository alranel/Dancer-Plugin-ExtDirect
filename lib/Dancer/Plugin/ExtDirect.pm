package Dancer::Plugin::ExtDirect;
use strict;
use warnings;

our $VERSION = '0.10';

use Dancer ':syntax';
use Dancer::Plugin;

register extdirect => sub ($) {
    my $init = shift;
    
    # validate config hashref
    $init->{api}
        or die "'api' route handler required\n";
    
    ref $init->{actions} eq 'HASH'
        or die "'actions' parameter required\n";
    
    get $init->{api} => sub {
        my $actions = {};
        foreach my $class (keys %{$init->{actions}}) {
            $actions->{$class} = [];
            foreach my $method (keys %{$init->{actions}{$class}}) {
                push @{$actions->{$class}}, {
                    name  => $method,
                    len   => $init->{actions}{$class}{$method}{len},
                };
            }
        }
        
        content_type 'text/javascript';
        sprintf "Ext.app.REMOTING_API = %s;\n",
            to_json {
                url       => request->path . '/router',
                type      => 'remoting',
                actions   => $actions,
            };
    };
    
    post $init->{api} . '/router' => sub {
        my @splat = splat;
        
        my $requests = from_json(request->body)
            or return status 400;
        
        # wrap the request if we didn't get an array
        $requests = [ $requests ] if ref $requests ne 'ARRAY';
        
        # check whether we can accept the incoming requests
        foreach my $request (@$requests) {
            $init->{actions}{$request->{action}}
                && $init->{actions}{$request->{action}}{$request->{method}}
                && $init->{actions}{$request->{action}}{$request->{method}}{len} == scalar(@{$request->{data}})
                    or return status 400;
        }
        
        # process requests
        my @results = ();
        foreach my $request (@$requests) {
            my $handler = $init->{actions}{$request->{action}}{$request->{method}}{handler};
            push @results, {
                type    => 'rpc',
                tid     => $request->{tid},
                action  => $request->{action},
                method  => $request->{method},
                result  => $handler->(@splat, @{$request->{data}}),
            };
        }
        
        # return results
        content_type 'application/json';
        to_json \@results;
    };
};

register_plugin;

1;
