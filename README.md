Reputation API
==============

A Reputation API é uma API de reputação para endereços IP, urls, localidades, pessoas, etc... Ela é construida de maneira a tornar seu uso portável para qualquer que seja o objeto a ter sua reputação arquivada.


Instalacao
----------

Para usar a Reputation API você precisa instalar os seguintes modulos Perl:

* [MongoDB](https://metacpan.org/pod/MongoDB) -- Usado para integração com o banco de dados
* [Mojolicious::Lite](http://mojolicio.us/perldoc/Mojolicious/Lite) -- Usado como framework web
* [Mojo::JSON](http://mojolicio.us/perldoc/Mojo/JSON) -- Usado para ler JSON como um hash
* [Mojo::Log](http://mojolicio.us/perldoc/Mojo/Log) -- Usado para o envio de eventos localmente
* [Readonly](https://metacpan.org/pod/Readonly) -- Usado para gerar as constantes
* [Data::Printer](https://metacpan.org/pod/Data::Printer) -- Usado para debug de variáveis
* [Hash::Merge](https://metacpan.org/pod/Hash::Merge) -- Usado para mesclar resultados (útil quando o resultado vem de lugares diferentes)
* [Net::Syslog](https://metacpan.org/pod/Net::Syslog) -- Usado para o envio de eventos via syslog

Se você estiver instalando somente para testar, você pode executar:

	cpanm MongoDB Mojolicious::Lite Mojo::JSON Mojo::Log Readonly Data::Printer Hash::Merge Net::Syslog

Se você estiver instalando a aplicação para um ambiente de produção, é recomendável que você faça uso da [local::lib](https://metacpan.org/pod/local::lib) para não modificar o Perl instalado em seu sistema. Outra alternativa é usar o [perlbrew](http://perlbrew.pl/).

Para instalar o locallib é recomendado que você crie um usuário limitado para sua aplicação, no caso, você pode criar um usuário chamado `reputation` e instalar o [local::lib](https://metacpan.org/pod/local::lib) no home desse usuário.

	cpanm local::lib

Após instalar é necessário acrescentar no arquivo `.bashrc` ou `.profile` as variáveis de ambiente para a sua aplicação. Para obtê-las, execute `perl -Mlocal::lib`.

Após feita a instalação, use o script `start_reputation_api.sh` para iniciar a aplicação e `stop_reputation_api.sh` para parar a execução.


Configuração
------------

A configuração da API é toda feita por variáveis de ambiente. Um exemplo de configuração pode ser visto a seguir:

	export REPUTATION_API_MONGO_HOST="localhost"
	export REPUTATION_API_MONGO_PORT="27017"
	export REPUTATION_API_DATABASE="reputation"
	export REPUTATION_API_COLLECTIONS="ip url"
	export REPUTATION_API_LOG="LOCAL"
	export REPUTATION_API_VALID_DETECTION_METHODS="darknet honeypot manual scan"
	export REPUTATION_API_VALID_STATUS="infected notified blocked malicious suspicious"

Nesse exemplo, colocamos os eventos para serem gerados localmente, logo deverá ser criada no diretório da aplicação uma pasta chamada `log`.

No exemplo a seguir, configuramos para o envio de eventos para um coletor remoto:

	export REPUTATION_API_MONGO_HOST="localhost"
	export REPUTATION_API_MONGO_PORT="27017"
	export REPUTATION_API_DATABASE="reputation"
	export REPUTATION_API_COLLECTIONS="ip url"
	export REPUTATION_API_LOG="NET"
	export REPUTATION_API_SYSLOG_HOST="192.168.0.32"
	export REPUTATION_API_SYSLOG_PORT="514"
	export REPUTATION_API_VALID_DETECTION_METHODS="darknet honeypot manual scan"
	export REPUTATION_API_VALID_STATUS="infected notified blocked malicious suspicious"

Nesse exemplo, os eventos serão enviados via Syslog para o host 192.168.0.32, na porta 514.


Uso
---

A Reputation API é uma API que tenta seguir os padrões REST. Assim, ela disponibiliza de forma fácil o obtenção e envio de dados.


### Contagem

	http://localhost:3000/api/1.0/ip/count

Produz uma resposta:

	{"total":2,"result":"sucesso"}

Onde `total` é a quantidade de itens (endereços IP).


### Contagem por status

	http://localhost:3000/api/1.0/ip/count?status=malicious

Produz uma resposta:

	{"total":1,"result":"sucesso"}

Onde `total` é a quantidade de itens (endereços IP) com status `malicious`.


### Contagem por detection

	http://localhost:3000/api/1.0/ip/count?detection=darknet

Produz uma resposta:

	{"total":1,"result":"sucesso"}

Onde `total` é a quantidade de itens (endereços IP) detectados atraves de `darknet`.


### Listagem

	http://localhost:3000/api/1.0/ip

Produz uma resposta:

	{
	    "result": "sucesso",
	    "itens": [{
	        "_id": {
	            "$oid": "52ee6416fd513d7e397cab94"
	        },
	        "detection": "darknet",
	        "created": 1391266128,
	        "ip": "192.168.8.10",
	        "report_time": 1391266128,
	        "counter": 10,
	        "status": "malicious"
	    }, {
	        "created": 1391266128,
	        "counter": 10,
	        "status": "infected",
	        "ip": "192.168.8.1",
	        "report_time": 1391266128,
	        "detection": "darknet",
	        "_id": {
	            "$oid": "52ee6443fd513d7e397cab95"
	        }
	    }]
	}

Onde `itens` é um array com os itens na base IP.


### Listagem por status

	http://localhost:3000/api/1.0/ip?status=malicious

Produz uma resposta:

	{
	    "itens": [{
	        "created": 1391266128,
	        "counter": 10,
	        "status": "malicious",
	        "report_time": 1391266128,
	        "ip": "192.168.8.10",
	        "_id": {
	            "$oid": "52ee6416fd513d7e397cab94"
	        },
	        "detection": "darknet"
	    }],
	    "result": "success"
	}

Onde `itens` é um array com os endereços IP que estão com o `status` igual a `malicious`.


### Listagem por detection

	http://localhost:3000/api/1.0/ip?detection=honeypot

Produz uma resposta:

	{
	    "itens": [{
	        "created": 1391266128,
	        "status": "malicious",
	        "counter": 10,
	        "ip": "192.168.8.10",
	        "report_time": 1391266128,
	        "detection": "darknet",
	        "_id": {
	            "$oid": "52ee6416fd513d7e397cab94"
	        }
	    }, {
	        "detection": "darknet",
	        "_id": {
	            "$oid": "52ee6443fd513d7e397cab95"
	        },
	        "counter": 10,
	        "status": "infected",
	        "report_time": 1391266128,
	        "ip": "192.168.8.1",
	        "created": 1391266128
	    }],
	    "result": "success"
	}

Onde `itens` é um array com os endereços IP que estão com o `detection` igual a `honeypot`.


### Obtendo item

	http://localhost:3000/api/1.0/ip/192.168.8.1

Produz uma resposta com os dados do item pedido:

	{
	    "report_time": 1391266128,
	    "status": "infected",
	    "counter": 10,
	    "created": 1391266128,
	    "_id": {
	        "$oid": "52ee6443fd513d7e397cab95"
	    },
	    "detection": "darknet",
	    "ip": "192.168.8.1",
	    "result": "success"
	}


### Inserindo item

	curl -X PUT 'http://localhost:3000/api/1.0/ip/192.168.8.91?status=malicious&detection=scan'

Produz uma resposta conforme a seguir em caso de sucesso:

	{"result":"success"}

Caso ocorra erros, a API responde:

	{"code":"504","result":"error","message":"Item nao encontrado na colecao!"}

Ou, caso o erro não seja rastreável:

	{"result":"error"}


### Inserindo evidencias ou objetos


A API fornece a possibilidade de serem arquivadas as evidencias que comprovem a reputacao de um ativo, seja ele qual for. Nesses casos, como a informação pode ser um log, flow, etc é recomndado que um objeto JSON seja enviado com a informação. Como não é possível enviar esse objeto como um parâmetro na URL, basta colocar `body` no lugar que a API usa o conteúdo no `body` do PUT.

	curl -X PUT --data '{"ip":"192.168.0.3","access-list":"24","action":"deny"}' 'http://localhost:3000/api/1.0/acl/body?status=malicious&detection=scan'

Produz uma resposta conforme a seguir em caso de sucesso:

	{"result":"success"}

Assim como as outras no caso acima.


### Modificando um item

Embora a operacao seja bem semelhante a insercao, criamos uma secao separada para ilustrar alguns casos. Suponha que o host tenha sido bloqueado, voce poderia ter feito:

	curl -X PUT 'http://localhost:3000/api/1.0/ip/192.168.8.91?status=blocked&detection=manual'

Produz uma resposta conforme a seguir em caso de sucesso:

	{"result":"success"}

Assim como as outras nos casos acima.


Licenciamento
-------------

Esse software é livre e deve ser distribuido sobre os termos a Apache License v2.


Autor
-----

Copyrigth [Manoel Domingues Junior](http://github.com/mdjunior) <manoel at ufrj dot br>
