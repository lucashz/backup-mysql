#!/bin/bash 
## Script: 
# Criado por: Lucas Bulow
# backup de backup de db mysql
# retenção configurado para 7 dias
# move pra fora do host
# manda email de sucesso/falha



#FILE=database.sql.`date +"%Y%m%d"`.gz
DBSERVER=192.168.65.227
#REMOTE_SERVER=192.168.65.227 # move pra fora do host
SRC_DIR=/opt/backup
#REMOTE_BACKUP_DIR=/backup/backupSQL
#DATABASE=dbname


# funcao manda email
# variaveis sendmail
NOW=`date "+%d_%m_%Y_%H%M"`
email_list=""
success_email="";
failure_email="";
START=$(date +%s)


sendEmail() {
        scripttime=0;
        END=$(date +%s)
        DIFF=$(( $END - $START ))
        if [ $DIFF -le 60 ]; then
                scripttime="$DIFF seconds.";
        else
                DIFF=$(( $DIFF / 60 ))
                scripttime="$DIFF minutes.";
        fi;
        content="$content. Log: Tempo duração backup: $scripttime"
        echo $content  | mail -s "$subject"  $email_list
        exit;
}

# pipeline que retorna se o comando da falha
set -o pipefail

##### Variaveis 
declare DATA=`date +%d_%m_%Y`
declare DATA2=`date +%d %m %Y %H:%M`
declare DIR_BACKUP="/opt/backup"  #  Define o diretório de backup
declare SENHA=""
declare USER="root"
declare CDB="/opt/backup/consulta_tam_db.sql"
DIR_DEST_BACKUP=$DIR_BACKUP/$DATA/
###################################################################

##### Rotinas secundarias
mkdir -p $DIR_BACKUP/$DATA # Cria o diretório de backup diário
echo > $DIR_BACKUP/$DATA/backup.log #RTA pra bug na permissão do log
chmod 777 $DIR_BACKUP/$DATA/backup.log #RTA parte 2
chmod -R 777 /opt/backup/$DATA/ # Da permissão para o diretório criado acima
mysql -u $USER -p$SENHA < $CDB >> $DIR_BACKUP/$DATA/backup.log #FAZ SELECT DO TAMANHO DOS DBS E INSERE DENTRO DO LOG
echo "##################################################" >> $DIR_BACKUP/$DATA/backup.log
echo "MYSQL"
echo "$(tput setab 7)##################################$(tput sgr 0)"
echo "$(tput bold)Iniciando backup do banco de dados $(tput sgr 0)"
##################################################################

# função que executa o backup
executa_backup(){
echo "Inicio do backup $DATA2"
 #Recebe os nomes dos bancos de dados na maquina destino
 BANCOS=$(mysql -u $USER -p$SENHA -e "show databases")
 #retira palavra database
 #BANCOS=${BANCOS:9:${#BANCOS}}

declare CONT=0

#inicia o laço de execução dos backups 
for banco in $BANCOS
 do
 if [ $CONT -ne 0 ]; then    # ignora o primeiro item do array, cujo conteudo é "databases"
     NOME="backup_"$banco"_"$DATA".sql" #variavel pra setar dump
	NOMET="backup_"$banco"_"$DATA"" #variavel pra setar compress

    echo "Iniciando backup do banco de dados [$banco]"
   # comando que realmente executa o dump do banco de dados 
    mysqldump --hex-blob --lock-all-tables -u $USER -p$SENHA --databases $banco > $DIR_BACKUP/$DATA/$NOME
		cd $DIR_BACKUP/$DATA/
		tar -czf $NOMET.tar.gz $NOME
		rm $DIR_BACKUP/$DATA/$NOME*
	
   # verifica que se o comando foi bem sucedido ou nao.
   if [ $? -eq 0 ]; then
      echo "Backup Banco de dados [$banco] completo"
   else
      echo "ERRO ao realizar o Backup do Banco de dados [$banco]"
   fi

fi
 CONT=`expr $CONT + 1`
 done


echo "Final do backup: $DATA2"
}

executa_backup 2>> $DIR_DEST_BACKUP/backup.log 1>> $DIR_DEST_BACKUP/backup.log 1>> $DIR_DEST_BACKUP/backup.log

# verifica falha e manda email
RESULT=$?
if [ $RESULT -ne 0 ]; then
        subject="Backup-FAILURE";
        content="O backup falhou em: $NOW. O comando de gerar o dump retornou algum erro. Por favor acesse $DBSERVER e verifique o status."
        email_list=$failure_email
        echo "[`date`]Backup failure."
        sendEmail
fi

# move para remote host
#scp ${SRC_DIR}/${FILE} root@${REMOTE_SERVER}:${REMOTE_BACKUP_DIR} 2>/dev/null
#RESULT=$?
#if [ $RESULT -ne 0 ]; then
#        subject="Backup-FAILURE";
#        content="O Backup foi concluído $NOW. Mas não conseguimos fazer o SCP."
#        email_list=$failure_email
#        echo "[`date`]SCP failure."
#        sendEmail
#fi

# retencao remote host
#BACKUP_FILE=${REMOTE_BACKUP_DIR}/database.sql.`date -d"-7 days" +"%Y%m%d"`.gz 2>/dev/null
#echo "[`date`] Removendo arquivo de backup: $BACKUP_FILE from ${REMOTE_SERVER}."
#ssh root@${REMOTE_SERVER} "rm $BACKUP_FILE" 2>/dev/null
# 7 DIAS RETENÇÃO.
find $SRC_DIR -mtime +7 -name '*.gz' -exec rm {} \;

# verifica sucesso e manda email.
subject="Backup-SUCCESS"
content="O backup foi finalizado com sucesso no diretório: $SRC_DIR. No servidor: $REMOTE_SERVER"
content=$content.`$DIR_BACKUP/$DATA/backup.log`
email_list=$success_email;
echo "[`date`]Backup Success."
sendEmail
exit 0;

