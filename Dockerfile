FROM debian:wheezy

MAINTAINER Halid Altuner "haltuner@turksat.com.tr"

ENV DEBIAN_FRONTEND noninteractive
ENV APP_PATH=/opt/pns

# policy.d setting
RUN echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d

# installing required packages
RUN apt-get -qq update
RUN apt-get -qqy install --force-yes git-core curl python-dev python-pip libffi-dev ca-certificates apt-utils wget

# installing node.js via package manager
RUN curl -sL https://deb.nodesource.com/setup | bash -
RUN apt-get -qqy install --force-yes nodejs

# PostgreSQL apt-key and repository
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ wheezy-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN apt-get update

# Installing PostgreSQL 9.4
RUN apt-get -qqy install --force-yes postgresql-9.4 postgresql-server-dev-9.4

# Cloning Turksat PNS project with github and installing
RUN mkdir /opt/pns
RUN pip install virtualenvwrapper
RUN virtualenv --no-site-packages /opt/pns/env
RUN /bin/bash -c 'source /opt/pns/env/bin/activate'
RUN git clone https://github.com/Turksat/pns.git /opt/pns/pns
RUN pip install -r /opt/pns/pns/requirements.txt
RUN npm install --silent -g apidoc
RUN cd /opt/pns/pns && apidoc -i ./ -o apidoc/

RUN cp /opt/pns/pns/config_sample.ini /opt/pns/config.ini
VOLUME  ["/opt/pns"]
# RabbitMQ apt-key and repository
RUN echo "deb http://www.rabbitmq.com/debian/ testing main" > /etc/apt/sources.list.d/rabbitmq.list
RUN wget --quiet -O - http://www.rabbitmq.com/rabbitmq-signing-key-public.asc | apt-key add -
RUN apt-get -qq update

# installing system packages
RUN apt-get -qqy install --force-yes rabbitmq-server supervisor 
RUN service rabbitmq-server start

# Configuring PostgreSQL...
USER postgres
RUN    /etc/init.d/postgresql start &&\
	psql --command "CREATE USER docker WITH SUPERUSER PASSWORD 'docker';" &&\
	createdb -O docker pns
RUN echo "host all  all    127.0.0.1/32  md5" >> /etc/postgresql/9.4/main/pg_hba.conf
RUN echo "listen_addresses='127.0.0.1'" >> /etc/postgresql/9.4/main/postgresql.conf 
EXPOSE 5432
VOLUME  ["/etc/postgresql", "/var/log/postgresql", "/var/lib/postgresql"]
CMD ["/usr/lib/postgresql/9.4/bin/postgres", "-D", "/var/lib/postgresql/9.4/main", "-c", "config_file=/etc/postgresql/9.4/main/postgresql.conf"]
