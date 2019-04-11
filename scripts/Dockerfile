FROM mysql:5.7.10

# https://stackoverflow.com/questions/30740828/commit-data-in-a-mysql-container
RUN cp -r /var/lib/mysql /var/lib/mysql-no-volume
RUN cp -r /etc/mysql/my.cnf /etc/mysql/my.cnf-original
RUN sed -i -e "s|/var/lib/mysql|/var/lib/mysql-no-volume|" /etc/mysql/my.cnf
