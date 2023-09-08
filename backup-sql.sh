#!/bin/bash

# пример команды для настройки автоматического запуска скрипта каждый день в 01:05 кроме сб и вск (строчка для crontab):
# 05 01 * * 1-5 /home/pavel/backup-sql.sh /home/pavel/backup.config

source $1

set -o pipefail

# этой строчкой можно включить остановку скрипта при первой ошибке.
#set -o errexit

log_file=$BACKUP_PATH/$BACKUP_PREFIX.$(date +"%Y.%m.%d_%H%M%S").log
temp_file=$BACKUP_PATH/temp.sql

trap 'rm -f $temp_file' EXIT
trap 'echo -e "$(date +"%F %T") $error_message" | tee -a $log_file ' ERR

# проверка существования каталога BACKUP_PATH
error_message="Ошибка при создании каталога $BACKUP_PATH или лог-файла $log_file."
if [ ! -d "$BACKUP_PATH" ]
then
	echo "Указанного каталога для хранения копий не существует."
	echo "Создание каталога $BACKUP_PATH."
	mkdir $BACKUP_PATH
	echo "$(date +"%F %T") Каталог $BACKUP_PATH создан." | tee -a $log_file
fi

# проверка наличия свободного места на диске
required_space=1024 # необходимое место в мегабайтах (лучше поместить в config)
available_space=$(df -P $BACKUP_PATH | awk 'NR==2 {print $4}') # доступное место в килобайтах

# сравнение в килобайтах, т.к. так сравнение более точное
if [ $((required_space * 1024)) -gt "$available_space" ]
then
	# вывод в мегабайтах т.к. так более читабельно
	echo "$(date +"%F %T") Ошибка: недостаточно свободного места на диске. Необходимо $required_space мегабайт, доступно $((available_space / 1024)) мегабайт." | tee -a $log_file
	exit 1
fi

echo "$(date +"%F %T") Начало процедуры резервного копирования." | tee -a $log_file

# создание резервной копии
error_message="Ошибка при создании резервной копии базы данных:"
pg_dump postgresql://$DB_USER:$DB_PASS@$DB_HOST/$DB_BASE > $temp_file 2>&1

if [ $? -eq 0 ]
then
	# здесь temp_file содержит бэкап
	gzip -9 -c $temp_file > $BACKUP_PATH/$BACKUP_PREFIX.$(date +"%Y.%m.%d_%H%M%S").tar.gz
else
	# здесь temp_file содержит сообщения об ошибках
	cat $temp_file | tee -a $log_file
	exit 1
fi

# при set -o errexit if лучше убрать и использовать временный файл для ошибок: 
#trap 'echo -e "$(date +"%F %T") $(cat $error_file)" | tee -a $log_file ' ERR
#pg_dump postgresql://$DB_USER:$DB_PASS@$DB_HOST/$DB_BASE > $temp_file 2> $error_file
#gzip -9 -c $temp_file > $BACKUP_PATH/$BACKUP_PREFIX.$(date +"%Y.%m.%d_%H%M%S").tar.gz

# можно также обойтись без временного файла temp_file, однако в случае ошибки 
# всё равно создатся файл .tar.gz, его нужно будет удалить
#pg_dump postgresql://$DB_USER:$DB_PASS@$DB_HOST/$DB_BASE | gzip -k9 > $BACKUP_PATH/$BACKUP_PREFIX.$(date +"%Y.%m.%d_%H%M%S").tar.gz

echo "$(date +"%F %T") Окончание процедуры резервного копирования." | tee -a $log_file

# удаление лишних файлов
error_message="Ошибка при нахождении файлов копий и логов."
backup_copies=$(find $BACKUP_PATH -name '*.tar.gz' | sort)
backup_copies_num=$(echo "$backup_copies" | wc -l)
	echo "$backup_copies"

# следующие переменные можно использовать вместо для удаления и старых копий, и старых логов. При этом backup_copies необходимо заменить на backup_files, backup_copies_num - backup_files_num.
# В этом случае число BACKUP_COUNT будет содержать суммарное число копий и логов. Так, BACKUP_COUNT=10 означает хранение 5 копий и 5 логов. 
#backup_files=$(find $BACKUP_PATH \( -name '*.tar.gz' -o -name '*.log' \) | sort)
#backup_files_num=$(echo "$backup_files" | wc -l)

if [ $backup_copies_num -gt $BACKUP_COUNT ]
then
	error_message="Ошибка при удалении старых копий и логов."
	echo "$(date +"%F %T") Число резервных копий $backup_copies_num, что превышает допустимое число копий $BACKUP_COUNT. Удаление лишних копий." | tee -a $log_file
	echo "$backup_copies" | head -n $((backup_files_num-BACKUP_COUNT)) | xargs rm -v | tee -a $log_file
fi

