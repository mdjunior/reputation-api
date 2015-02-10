# reputation-api
###### API for data reputation (like ip, emails, urls, domains...)
------------------------------------------------------------------

A seguinte API tem por fincalidade servir como ponto central para controle de reputação de objetos, sendo alguns exemplos sugeridos:
* ip
* url
* software
* email
* domain
* username
* filehash
* filename
* certhash

A opção por criar uma API para fazer a gestão desses dados é especializar as informações geradas por diversos sistemas de segurança dentro de uma organização e atribuir um peso para cada evento gerado. Esse peso, chamaremos de tax e a classificação dos eventos será feita através de categorias.

Assim, para cada categoria de evento, teremos uma tax associada e essa tax pode aumentar a reputação de um objeto ou diminuir, tudo isso de acordo com a categoria do evento.


######## Instalação
===================

O processo de instalação da API depende basicamente de uma conexão com a internet e da execussão de alguns comandos (que podem ser facilmente automatizados). Para sistemas operacionais com versões antigas de Perl (a API é escrita nessa linguagem) recomendamos o uso do Plenv, que é capaz de criar um ambiente virtual com o Perl na versão ideal.

Para sistemas mais modermos (com versões do Perl acima da 5.18.2), o Perl do sistema pode ser usado.

O primeiro passo, é fazer o download da aplicação. Isso pode ser feito clonando o repositório ´git clone https://github.com/mdjunior/reputation-api.git´ ou fazendo o download do ZIP [aqui](https://github.com/mdjunior/reputation-api/archive/master.zip)

Feito isso, basta entrar na pasta e executar ´./vendor/bin/carton install --cached --deployment´. Agora basta configurar a aplicação.


######## Configuração
=====================

Toda a configuração da aplicação é feita usando variáveis de ambiente, logo sempre que alguma ação relativa a iniciar ou parar a aplicação, as variáveis de ambiente deverão ser carregadas.

Caso você não tenha ideia de como fazer isso, uma dica é gravar as variáveis de ambiente em um arquivo, que somente um usuário administrador ler e executar. Fazendo isso, basta executar o comando ´source arquivo.sh´ e você carregará as variáveis de ambiente para o ambiente atual.

A seguir, acompanhe as variáveis de ambiente utilizadas, com exemplos de configuração:

	REPUTATION_API_COLLECTIONS="ip url software email domain username filehash filename certhash"
	REPUTATION_API_REDIS_URL="redis://x:auth_key\@localhost:6379/0"
	REPUTATION_API_DB_NAME="reputation"
	REPUTATION_API_DB_HOST="localhost"
	REPUTATION_API_DB_USER="root"
	REPUTATION_API_DB_PASS="21916-7739-23119-1183"


	REPUTATION_API_WORKERS=4
	REPUTATION_API_CLIENTS=100
	REPUTATION_API_LOCK_FILE=reputation-api.lock
	REPUTATION_API_PID_FILE=reputation-api.pid

######## Uso
============


######### /status
-----------------

Rota de verificação do funcionamento da API. Seu uso é recomendado para aplicações que farão um alto número de requisições em um curto espaço de tempo, assim verificando se a API está disponível. Exemplo de consulta:

	curl $HOST/status

Resposta

	WORKING

