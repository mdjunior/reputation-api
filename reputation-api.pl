#!/usr/bin/env perl
###############################################################################
#
# API for data reputation (like ip, emails, urls, domains...)
#
###############################################################################

###############################################################################
package Main;
###############################################################################

use strict;
use warnings;
use Mojolicious::Lite;
use Mojo::JSON qw(j);
use DBI;
use DBD::mysqlPP;
use Mojo::Redis2;
use Readonly;

our $VERSION = 1.0;

###############################################################################
Readonly my $DEFAULT_VALUE => 100;
Readonly my $EXPIRATION    => 86_400;
Readonly my @COLLECTIONS   => split / /sm, $ENV{REPUTATION_API_COLLECTIONS};
###############################################################################

###############################################################################
## Helper for redis
helper redis => sub {
    shift->stash->{redis}
        ||= Mojo::Redis2->new(url => $ENV{REPUTATION_API_REDIS_URL});
};

###############################################################################
## Helper for mysql
my $dbh = DBI->connect(
    "DBI:mysqlPP:$ENV{REPUTATION_API_DB_NAME}:$ENV{REPUTATION_API_DB_HOST}",
    $ENV{REPUTATION_API_DB_USER},
    $ENV{REPUTATION_API_DB_PASS}
) or exit;
helper db => sub {$dbh};

helper get_tax => sub {
    my $self = shift;
    my ($cat, $others) = @_;

    my $sth = eval {
        $self->db->prepare(
            'SELECT tax FROM category WHERE category=? LIMIT 1');
    };
    $sth->execute($cat);
    return $sth->fetchall_arrayref()->[0]->[0];
};

helper insert_event => sub {
    my $self = shift;
    my ($time, $collection, $item, $cat, $msg, $log_id) = @_;

    my $sth = eval {
        $self->db->prepare(
            'INSERT INTO `events` (`timestamp`,`collection`,`item`,`category`,`msg`,`log_id`) VALUES (?,?,?,?,?,?);'
        );
    };
    $sth->execute($time, $collection, $item, $cat, $msg,
        $collection . $log_id);
    return 1;
};
###############################################################################

get '/status' => sub {
    my $c      = shift;
    my $status = 'WORKING';

#  is not necessary to check the mysql because the application does not start without it

    #  checking redis
    my $res = $c->redis->set(foo => '42');
    $res = $c->redis->get('foo');
    if ($res ne '42') {
        $status = 'FAIL';
    }

    $c->render(text => $status);
};

get '/api/:collection/#item' => [collection => @COLLECTIONS] => sub {
    my $c = shift;

    $c->delay(
        sub {
            my ($delay) = @_;
            $c->redis->zscore($c->param('collection'),
                $c->param('item'), $delay->begin);
        },
        sub {
            my ($delay, $err, $msg) = @_;

            # If already have reputation
            if (defined $msg) {
                $c->render(json => {reputation => $msg * 1});
                return;
            }

            # If it has no reputation
            else {
                $c->redis->zadd(
                    $c->param('collection'),
                    $DEFAULT_VALUE => $c->param('item'),
                    $delay->begin
                );
                $c->render(json => {reputation => $DEFAULT_VALUE * 1});
                return;
            }
        },
    );
};

post '/api/:collection' => [collection => @COLLECTIONS] => sub {
    my $c = shift;

    my $item = j($c->req->body);

    # Validating JSON
    if (   !defined $item->{timestamp}
        || !defined $item->{item}
        || !defined $item->{category}
        || !defined $item->{msg}
        || !defined $item->{log_id})
    {
        $c->render(text => 'error', status => 400);
        return;
    }

    # Getting the tax by category
    my $tax = $c->get_tax($item->{category});
    if (!defined $tax) {
        $c->render(text => 'error', status => 400);
        return;
    }

    # Verifying if exists reputation, and setting it in case of failure
    my $reputation;
    $c->delay(
        sub {
            my ($delay) = @_;
            $c->redis->zscore($c->param('collection'),
                $item->{item}, $delay->begin);
        },
        sub {
            my ($delay, $err, $msg) = @_;

            # If it has reputation (multiply the tax by the current value)
            if (defined $msg) {
                $reputation = $msg * $tax;

            # If it has not reputation (multiply the tax by the standard value)
            }
            else {
                $c->app->log->info('opa...');
                $reputation = $DEFAULT_VALUE * $tax;
            }

            # Recording reputation
            $c->redis->zadd($c->param('collection'),
                $reputation => $item->{item});

            # Inserting event
            $c->insert_event($item->{timestamp}, $c->param('collection'),
                $item->{item}, $item->{category}, $item->{msg},
                $item->{log_id},);

            $c->render(json => {'reputation' => $reputation});
            return;
        },
    );
};


app->config(
    hypnotoad => {
        listen    => ['http://*:8080'],
        workers   => $ENV{REPUTATION_API_WORKERS},
        clients   => $ENV{REPUTATION_API_CLIENTS},
        lock_file => $ENV{REPUTATION_API_LOCK_FILE},
        pid_file  => $ENV{REPUTATION_API_PID_FILE},
    }
);

app->log->level('debug');
app->start;
