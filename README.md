# backup_postgresql
Bash-скрипт резервного копирования базы данных PostgreSQL, который:
- Соединяется с сервером PostgreSQL под указанными login/password.
- Делает снимок состояния базы `DB_BASE` в файл BACKUP_PATH/BACKUP_PREFIX.гггг.мм.дд_ччммсс.tar.gz.
- Проверяет, что число копий базы данных в BACKUP_PATH >= BACKUP_COUNT, а в случае, > BACKUP_COUNT удаляет лишнее начиная с самых старых.
- Обрабатывает ошибки нехватки свободного места и ошибки во время выполнения резервной копии, а также явно указывает тип ошибки, время её возникновения.
- Ведёт журнал сообщений BACKUP_PATH/BACKUP_PREFIX.гггг.мм.дд_ччммсс.log и дублирует сообщения в stdout:
  - дата-время начала и окончания процедуры резервного копирования,
  - вышеозначенные сообщения об ошибках, системные сообщения об ошибках, или сообщения об ошибках со стороны сервера и время их возникновения.

Запуск скрипта:

bash backup-sql.sh /путь/к/файлу/backup.config

где `/путь/к/файлу/backup.config` : путь к конфигурационному файлу скрипта, в котором содержится:
- DB_HOST - FQDN или IP серевера с базой данных PostgreSQL
- DB_USER - имя пользователя, под которым нужно подключаться к серверу
- DB_PASS - пароль
- DB_BASE - база данных, которую следует копировать
- BACKUP_PATH - локальный путь к каталогу, в котором хранятся резервные копии
- BACKUP_COUNT - количество хранимых резервных копий
