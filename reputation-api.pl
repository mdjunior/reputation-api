#!/usr/bin/env perl
###############################################################################
#
# API para dados de Reputacao de IPs
#
###############################################################################
#
# @ Manoel Domingues Junior mdjunior@ufrj.br
#
###############################################################################

###############################################################################
package Utils;
###############################################################################
use strict;
use warnings;
use Net::Syslog;
use Sys::Syslog;
use Readonly;

###############################################################################
Readonly my $IPV6_BLOCO_MIN => 128;
Readonly my $IPV6_BLOCO_MAX => 128;
Readonly my $IPV4_BLOCO_MIN => 24;
Readonly my $IPV4_BLOCO_MAX => 32;
###############################################################################

my %error = (
    '100' => 'Versao invalida!',
    '101' => 'Colecao nao utilizada!',
    '109' => 'Bloco IP invalido!',
    '300' => 'JSON invalido',
    '500' => 'Nao especificado IP para importacao!',
    '501' => 'Filtro de status invalido!',
    '502' => 'Filtro de detection invalido!',
    '504' => 'Item nao encontrado na colecao!',
    '505' => 'Status nao definido!',
    '506' => 'Detection nao definido!',

);

#######################################
# Funcao que loga
#######################################
sub log_wrapper {
    my $log = shift;

    if ( $ENV{REPUTATION_API_LOG} eq 'LOCAL' ) {
        openlog( 'REPUTATION_API', 'ndelay,pid', 'LOG_LOCAL0' );
        syslog( 'LOG_INFO', $log );
        closelog();
    }
    elsif ( $ENV{REPUTATION_API_LOG} eq 'NET' ) {
        my $log_net = Net::Syslog->new(
            Name       => 'REPUTATION_API',
            Facility   => 'local7',
            Priority   => 'info',
            SyslogPort => $ENV{REPUTATION_API_SYSLOG_PORT},
            SyslogHost => $ENV{REPUTATION_API_SYSLOG_HOST},
        );
        $log_net->send( $log, Priority => 'info' );
    }
    return;
}

#######################################
# Funcao que retorna os erros
#######################################
sub error {
    my $code = shift;
    my $info = shift;

    if ( !defined $info ) { $info = q{}; }

    Utils::log_wrapper("code=|$code| desc=|$error{$code}| info=|$info|");

    my %hash = (
        result  => 'error',
        code    => $code,
        message => $error{$code},
    );
    return \%hash;
}

sub valida_bloco {
    my $net  = shift;
    my $mask = shift;

    if ( !defined $mask ) {
        if ( is_ipv4($net) ) {
            $mask = $IPV4_BLOCO_MAX;
        }
        elsif ( is_ipv6($net) ) {
            $mask = $IPV6_BLOCO_MAX;
        }
    }

    if ( is_ipv4($net) ) {
        if ( $mask > $IPV4_BLOCO_MAX || $mask < $IPV4_BLOCO_MIN ) {
            return Utils::error( '109', "NET:$net MASK:$mask" );
        }
    }
    elsif ( is_ipv6($net) ) {
        if ( $mask > $IPV6_BLOCO_MAX || $mask < $IPV6_BLOCO_MIN ) {
            return Utils::error( '109', "NET:$net MASK:$mask" );
        }
    }
    my %hash = ( result => 'success', );
    return \%hash;
}

sub valida_status {
    my $status = shift;

    if ( $ENV{REPUTATION_API_VALID_STATUS} =~ /$status/smx ) {
        my %hash = ( result => 'success', );
        return \%hash;
    }

    return Utils::error( '501', $status );
}

sub valida_detection {
    my $detection = shift;

    if ( $ENV{REPUTATION_API_VALID_DETECTION_METHODS} =~ $detection ) {
        my %hash = ( result => 'success', );
        return \%hash;
    }
    return Utils::error( '502', $detection );
}

###############################################################################
package Model;
###############################################################################
use strict;
use warnings;
use MongoDB;
use Data::Printer alias => 'Dumper';
use Hash::Merge qw( merge );

my $client = MongoDB::MongoClient->new(
    host => $ENV{REPUTATION_API_MONGO_HOST},
    port => $ENV{REPUTATION_API_MONGO_PORT}
);
my $db = $client->get_database( $ENV{REPUTATION_API_DATABASE} );

#######################################
# Funcao que conta a quantidade atuais de documentos em uma colecao
#######################################
sub count {
    my $collection = shift;
    my $filter     = shift;
    my $value      = shift;

    # Com filtro definido
    if ( defined $filter ) {

        # Verifica se eh status
        if ( $filter eq 'status' ) {
            my $validacao_status = Utils::valida_status($value);
            if ( $validacao_status->{result} eq 'success' ) {
                my $count = $db->get_collection($collection)
                  ->find( { $filter => "$value" } )->count;
                my %hash = (
                    result => 'success',
                    total  => $count,
                );
                return \%hash;
            }
            else { return $validacao_status; }
        }
        elsif ( $filter eq 'detection' ) {
            my $validacao_detection = Utils::valida_detection($value);
            if ( $validacao_detection->{result} eq 'success' ) {
                my $count = $db->get_collection($collection)
                  ->find( { $filter => "$value" } )->count;
                my %hash = (
                    result => 'success',
                    total  => $count,
                );
                return \%hash;
            }
            else { return $validacao_detection; }
        }

        # Sem filtro definido
    }
    else {
        my $count = $db->get_collection($collection)->count;
        my %hash  = (
            result => 'sucesso',
            total  => $count,
        );
        return \%hash;
    }
}

#######################################
# Funcao que retorna os itens de uma colecao
#######################################
sub get_itens {
    my $collection = shift;
    my $filter     = shift;
    my $value      = shift;

    # Com filtro definido
    if ( defined $filter ) {

        # Verifica se eh status
        if ( $filter eq 'status' ) {
            my $validacao_status = Utils::valida_status($value);
            if ( $validacao_status->{result} eq 'success' ) {
                my $itens =
                  $db->get_collection($collection)
                  ->find( { $filter => "$value" } )
                  ->sort( { 'counter' => -1 } );
                my @all_itens = $itens->all;
                my %hash      = (
                    result => 'success',
                    itens  => \@all_itens,
                );
                return \%hash;
            }
            else { return $validacao_status; }

            # Verifica se eh detection
        }
        elsif ( $filter eq 'detection' ) {
            my $validacao_detection = Utils::valida_detection($value);
            if ( $validacao_detection->{result} eq 'success' ) {
                my $itens =
                  $db->get_collection($collection)
                  ->find( { $filter => "$value" } )
                  ->sort( { 'counter' => -1 } );
                my @all_itens = $itens->all;
                my %hash      = (
                    result => 'success',
                    itens  => \@all_itens,
                );
                return \%hash;
            }
            else { return $validacao_detection; }

            # Verifica se eh item
        }
        elsif ( $filter eq 'item' ) {
            my $itens = $db->get_collection($collection)
              ->find( { $collection => "$value" } );
            my $item = $itens->next;
            if ($item) {
                my %hash = ( result => 'success', );
                my %all_info = %{ merge( $item, \%hash ) };
                return \%all_info;
            }
            else { return Utils::error( '504', $value ); }
        }

        # Sem filtro definido
    }
    else {
        my $itens =
          $db->get_collection($collection)->find()->sort( { 'counter' => -1 } );
        my @all_itens = $itens->all;
        my %hash      = (
            result => 'sucesso',
            itens  => \@all_itens,
        );
        return \%hash;
    }
}

#######################################
# Funcao que insere um item na coleção
#######################################
sub put_item {
    my $collection = shift;
    my $item       = shift;
    my $status     = shift;
    my $detection  = shift;

    my $count_item =
      $db->get_collection($collection)->find( { $collection => "$item" } )
      ->count;

    # Inserindo um novo registro
    if ( $count_item == 0 ) {
        Utils::log_wrapper( 'action=|insert_new_item| info=|'
              . Dumper($item)
              . "| collection=|$collection| status=|$status| detection=|$detection|"
        );
        my %hash = (
            $collection => $item,
            counter     => 1,
            status      => $status,
            detection   => $detection,
            created     => time,
            report_time => time,
        );
        $db->get_collection($collection)->insert( \%hash );
        my %result = ( result => 'success', );
        return \%result;

        # Item ja existe
    }
    else {
        my $itens =
          $db->get_collection($collection)->find( { $collection => "$item" } );
        my $doc = $itens->next;

        # Status que eh prioritario caso informado
        if ( $status eq 'blocked' || $status eq 'notified' ) {
            Utils::log_wrapper(
"action=|modify_item| info=|$item| collection=|$collection| status=|$status|"
            );
            $db->get_collection($collection)
              ->update( { $collection => "$item" },
                { '$set' => { status => $status, report_time => time } } );

        }
        elsif ( $status eq 'malicious' ) {
            Utils::log_wrapper(
"action=|modify_item| info=|$item| collection=|$collection| status=|$status|"
            );

            # Mesmo status de antes -> incrementa
            if ( $doc->{status} eq 'malicious' ) {
                $db->get_collection($collection)->update(
                    { $collection => "$item" },
                    {
                        '$inc' => { counter     => 1 },
                        '$set' => { report_time => time }
                    }
                );

                # Status menor -> coloca como malicious
            }
            else {
                $db->get_collection($collection)
                  ->update( { $collection => "$item" },
                    { '$set' => { status => $status, report_time => time } } );
            }

        }
        elsif ( $status eq 'suspicious' ) {
            Utils::log_wrapper(
"action=|modify_item| info=|$item| collection=|$collection| status=|$status|"
            );

            # Mesmo status de antes -> incrementa
            if ( $doc->{status} eq 'suspicious' ) {
                $db->get_collection($collection)->update(
                    { $collection => "$item" },
                    {
                        '$inc' => { counter     => 1 },
                        '$set' => { report_time => time }
                    }
                );

                # Status de antes maior -> incremento
            }
            elsif ( $doc->{status} eq 'malicious' ) {
                $db->get_collection($collection)->update(
                    { $collection => "$item" },
                    {
                        '$inc' => { counter     => 1 },
                        '$set' => { report_time => time }
                    }
                );

                # Status de antes menor -> muda para o novo
            }
            elsif ( $doc->{status} eq 'infected' || $doc->{status} eq 'victim' )
            {
                $db->get_collection($collection)
                  ->update( { $collection => "$item" },
                    { '$set' => { status => $status, report_time => time } } );
            }

        }
        elsif ( $status eq 'victim' ) {
            Utils::log_wrapper(
"action=|modify_item| info=|$item| collection=|$collection| status=|$status|"
            );
            if ( $doc->{status} eq 'victim' ) {
                $db->get_collection($collection)->update(
                    { $collection => "$item" },
                    {
                        '$inc' => { counter     => 1 },
                        '$set' => { report_time => time }
                    }
                );
            }

            # Algum status valido nao registrado
        }
        else {
            Utils::log_wrapper(
"action=|modify_item| info=|$item| collection=|$collection| status=|$status|"
            );
            $db->get_collection($collection)
              ->update( { $collection => "$item" },
                { '$set' => { status => $status, report_time => time } } );
        }

        my %result = ( result => 'success', );
        return \%result;
    }
}

###############################################################################
package Main;
###############################################################################

use strict;
use warnings;
use Mojolicious::Lite;
use Mojo::JSON;
use Data::Printer alias => 'Dumper';
our $VERSION = 1.0;

get '/api/#version/:collection/count' => sub {
    my $self = shift;
    if ( $self->param('version') != $VERSION ) {
        $self->render( json => Utils::error( '100', $self->param('version') ) );
        return;
    }

    if ( $ENV{REPUTATION_API_COLLECTIONS} =~ /$self->param('collection')/smx ) {
        $self->render(
            json => Utils::error( '101', $self->param('collection') ) );
        return;
    }

    if ( defined $self->param('status') ) {
        $self->render(
            json => Model::count(
                $self->param('collection'), 'status',
                $self->param('status')
            )
        );
        return;
    }
    elsif ( defined $self->param('detection') ) {
        $self->render(
            json => Model::count(
                $self->param('collection'), 'detection',
                $self->param('detection')
            )
        );
        return;
    }
    else {
        $self->render( json => Model::count( $self->param('collection') ) );
        return;
    }
};

get '/api/#version/:collection' => sub {
    my $self = shift;

    if ( $self->param('version') != $VERSION ) {
        $self->render( json => Utils::error( '100', $self->param('version') ) );
        return;
    }
    if ( $ENV{REPUTATION_API_COLLECTIONS} =~ /$self->param('collection')/smx ) {
        $self->render(
            json => Utils::error( '101', $self->param('collection') ) );
        return;
    }

    if ( defined $self->param('status') ) {
        $self->render(
            json => Model::get_itens(
                $self->param('collection'), 'status',
                $self->param('status')
            )
        );
        return;
    }
    elsif ( defined $self->param('detection') ) {
        $self->render(
            json => Model::get_itens(
                $self->param('collection'), 'detection',
                $self->param('detection')
            )
        );
        return;
    }
    else {
        $self->render( json => Model::get_itens( $self->param('collection') ) );
        return;
    }
};

get '/api/#version/:collection/#item' => sub {
    my $self = shift;

    if ( $self->param('version') != $VERSION ) {
        $self->render( json => Utils::error( '100', $self->param('version') ) );
        return;
    }
    if ( $ENV{REPUTATION_API_COLLECTIONS} =~ /$self->param('collection')/smx ) {
        $self->render(
            json => Utils::error( '101', $self->param('collection') ) );
        return;
    }

    $self->render(
        json => Model::get_itens(
            $self->param('collection'),
            'item', $self->param('item')
        )
    );
};

put '/api/#version/:collection/#item' => sub {
    my $self = shift;

    if ( $self->param('version') != $VERSION ) {
        $self->render( json => Utils::error( '100', $self->param('version') ) );
        return;
    }
    if ( $ENV{REPUTATION_API_COLLECTIONS} =~ /$self->param('collection')/smx ) {
        $self->render(
            json => Utils::error( '101', $self->param('collection') ) );
        return;
    }

    if ( !defined $self->param('status') ) {
        $self->render( json => Utils::error('505') );
        return;
    }
    my $validacao_status = Utils::valida_status( $self->param('status') );
    if ( $validacao_status->{result} ne 'success' ) {
        $self->render( json => $validacao_status );
        return;
    }

    if ( !defined $self->param('detection') ) {
        $self->render( json => Utils::error('506') );
        return;
    }
    my $validacao_detection =
      Utils::valida_detection( $self->param('detection') );
    if ( $validacao_detection->{result} ne 'success' ) {
        $self->render( json => $validacao_detection );
        return;
    }

    if ( $self->param('item') eq 'body' ) {
        my $json = Mojo::JSON->new;
        my $res  = $json->decode( $self->req->body );
        if ( !defined $res ) {
            my $compact_body = $self->req->body;
            $compact_body =~ s/\n//gsmx;
            $self->render( json => Utils::error( '300', $compact_body ) );
            return Utils::error( '300', $compact_body );
        }
        $self->render(
            json => Model::put_item(
                $self->param('collection'), $res,
                $self->param('status'),     $self->param('detection')
            ),
            status => 201
        );
    }
    else {
        $self->render(
            json => Model::put_item(
                $self->param('collection'), $self->param('item'),
                $self->param('status'),     $self->param('detection')
            ),
            status => 201
        );
    }
};

app->start;
__DATA__
@@ exception.html.ep
{"result":"error"}

@@ not_found.html.ep
{"result":"error"}
