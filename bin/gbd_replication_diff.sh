#!/usr/bin/bash
#############################################################################
# Assumimos que na PATH se encontra PG_BASEDIR/bin (/postgresql/basedir/bin)
# Assumimos que existem as seguintes variaveis (definidas pelo setpg):
# GBD_FROM_EMAIL
# GBD_TO_EMAIL
# PG_BASEDIR
# PG_CLUSTER
# PG_ROOTDIR
#
# Assumimos que a lista de ficheiros a arquivar se encontra em
# PG_BASEDIR/etc
#
# 
#
#############################################################################

#### efetuar source de utilpg
. utilpg

#############################################################################
S_PROGNAME="${0##*/}"
S_HOSTNAME=$(hostname -s)

S_CONNECTION_STRING_MASTER="master.telecom.com:5432"
S_CONNECTION_STRING_SLAVE="slave.telecom.com:5432"
S_PSQL_BIN_PATH="${PG_DIR}/bin"
S_WAL_MAX_DIFF=5

S_COUNTERFULLPATHNAME="/tmp/gbd_replication_diff.counter"
S_TMPCOUNTERFULLPATHNAME="/tmp/gbd_replication_diff.tmp_counter"
S_LIMITE_ENVIO_EMAILS=3

#---------------------------------------------------------------------------
# MUDAR AS PATHS DE ACORDO COM A MAQUINA/AMBIENTE
S_ERR_MSG_FILE_DIR="${PG_ROOTDIR}/${PG_CLUSTER}/logs"
S_ERROR_MSG_FILE="${S_ERR_MSG_FILE_DIR}/${S_PROGNAME%%.*}_${PG_CLUSTER}_$(date -u +'%Y%m%dT%H%M%SZ').err"

S_PG_FROM_EMAIL="${GBD_FROM_EMAIL}"
S_PG_TO_EMAIL="${GBD_TO_EMAIL}"
#---------------------------------------------------------------------------

#### Variaveis para verificar se o script ja se encontra a executar
S_LOCK_DIR_NAME="/tmp/${S_PROGNAME%%.*}_${PG_CLUSTER}_lock"
L_LOCK_SET_THIS_RUN=0

####  Variavel que guarda o exit code que o script vai devolver
L_EXIT_STATUS_CODE=0

#---------------------------------------------------------------------------
# Function: show_help
#
#---------------------------------------------------------------------------
show_help()
{
    cat << EOF!
Usage: ${S_PROGNAME}
 Verifiy log replay delay between master and slave.
EOF!
}

#---------------------------------------------------------------------------
# Function: write_out
# Adiciona campos de logging ah mensagem: 
# timestamp hostname PID aplicacao tarefa nome_instancia : mensagem 
# 
# Argumentos:
# $1 - tipo de mensagem (ERROR|WARNING|INFO|FATAL|CRITICAL|DEBUG)
# $2 - mensagem
# 
#---------------------------------------------------------------------------
write_out()
{
    gbd_write_out "${S_HOSTNAME}" \
        "${PG_CLUSTER}" \
        "postgresql" \
        "${S_PROGNAME}" \
        "$1" \
        "$2"
}

#---------------------------------------------------------------------------
# Function: envia_mail
# Envia email em caso de erro/erros durante a execucao do script
#
#---------------------------------------------------------------------------
envia_mail()
{
    if [ -z "${S_PG_TO_EMAIL}" ]; then
        ## O endereco de email esta vazio, escrever mensagem para output e ficheiro de erro
        write_out "ERROR" "Nao foi encontrado endereco de email para enviar alerta (setpg)." | tee -a "${S_ERROR_MSG_FILE}"
    else
        sendmail -t << EOF!
FROM: ${S_PG_FROM_EMAIL}
TO: ${S_PG_TO_EMAIL}
SUBJECT: ERRO - Atraso na replicacao ${S_HOSTNAME}

This is an automatic generated mail created by the 
${S_PROGNAME} script at host ${S_HOSTNAME}
------------------------------------------------------------------

Atraso na replicacao.

DATETIME: $(date -u +'%Y%m%dT%H%M%SZ')

$(cat ${S_ERROR_MSG_FILE})    
 
------------------------------------------------------------------
.
EOF!
    fi
}

#-------------------------------------------------------------------------
# Function: script_cleanup
# Efetua a remocao da diretoria de lock
#
#-------------------------------------------------------------------------
function script_cleanup
{
    ## Limpar diretoria de lock
    gbd_cleanup_lock "${S_LOCK_DIR_NAME}" ${L_LOCK_SET_THIS_RUN} 
    write_out "INFO" "Fim da execucao do script [${S_PROGNAME}]."
    exit ${L_EXIT_STATUS_CODE}
}

#############################################################################
# Bloco principal do script

## Indicar inicio da execucao
write_out "INFO" "Inicio da execucao do script [${S_PROGNAME}]."
trap script_cleanup EXIT

## Usar um ciclo for que executa apenas 1 vez para no final verificar
## se eh necessario enviar alerta. O ciclo permite o uso de "break" 
## para parar execucao e enviar alerta.
for thisexecution in runonetime; do
    
    ## Verificar se PG_CLUSTER, PG_ROOTDIR, PG_BASEDIR existem (definido pelo setpg)
    if [ -z "${PG_CLUSTER}" ] || [ -z "${PG_ROOTDIR}" ] || [ -z "${PG_BASEDIR}" ] || [ -z "${PG_DIR}" ]; then
        ## Provavelmente nao foi efetuado o setpg 
        S_ERROR_MSG_FILE="/tmp/${S_PROGNAME%%.*}_$$_$(date -u +'%Y%m%dT%H%M%SZ').err"
        write_out "ERROR" "Nao foi encontrado valor de uma das variaveis PG_CLUSTER, PG_ROOTDIR, PG_BASEDIR, PG_DIR (setpg)." | tee -a "${S_ERROR_MSG_FILE}"
        L_EXIT_STATUS_CODE=101
        break        
    fi
    
    ## Mudar mascara dos ficheiros para novos ficheiros nao terem permissoes
    ## para group e others
    umask 0077
    if [ $? -ne 0 ]; then
        write_out "ERROR" "Nao foi possivel mudar a mascara para 0077." | tee -a "${S_ERROR_MSG_FILE}"
        L_EXIT_STATUS_CODE=101
        break
    fi

    # Usar mkdir para testar se existe alguma execucao anterior do script.
    # mkdir eh uma operacao "atomica", 2 scripts a executar ao "mesmo" tempo,
    # apenas 1 deles vai conseguir criar a diretoria.
    if ! mkdir "${S_LOCK_DIR_NAME}" 2>/dev/null; then
        # Diretoria de lock ja existe. Escrever mensagem e sair.
        write_out "WARNING" "Diretoria de lock [${S_LOCK_DIR_NAME}] ja existe." | tee -a "${S_ERROR_MSG_FILE}"
        L_EXIT_STATUS_CODE=101
        break
    else
        # Foi criada a diretoria de lock, colocar a variavel de controlo a 1
        # para que a funcao de cleanup remova a diretoria no fim.
        L_LOCK_SET_THIS_RUN=1
    fi
    
    #########################################################################
    ## ACTIONS BLOCK START
    #########################################################################

    gbd_monitor_hotstandby_v9x.sh -m "${S_CONNECTION_STRING_MASTER}" -s "${S_CONNECTION_STRING_SLAVE}" -b "${S_PSQL_BIN_PATH}" -n ${S_WAL_MAX_DIFF}
    L_EXIT_STATUS_CODE=$?
    if [ ${L_EXIT_STATUS_CODE} -eq 0 ]; then
        # Diferenca de WALs dentro dos limites, verificar se existe 
        
    else
    
    fi
    
    
    
    
    #########################################################################
    ## ACTIONS BLOCK END
    #########################################################################

done

## Verificar se deve enviar alerta
if [ ${L_EXIT_STATUS_CODE} -ne 0 ]; then
    envia_mail
fi
