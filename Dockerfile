FROM ubuntu:latest
RUN apt-get update
RUN apt-get -y install wget
RUN wget https://bitbucket.org/skskeyserver/sks-keyserver/downloads/sks-1.1.5.tgz
RUN tar -xzf sks-1.1.5.tgz

RUN apt-get -y install gcc ocaml libdb5.3-dev gnupg nginx 
RUN apt-get -y install make patch zlib1g-dev

WORKDIR sks-1.1.5
RUN cp Makefile.local.unused Makefile.local
RUN sed -i 's/ldb\-4.6/ldb\-5.3/' Makefile.local
RUN make dep
RUN make all
RUN make install

RUN mkdir /var/lib/sks
RUN mkdir /var/lib/sks/dump
WORKDIR /var/lib/sks/dump
RUN wget -c -r -p -e robots=off --timestamping --level=1 --cut-dirs=3 --no-host-directories http://keyserver.mattrude.com/dump/current/
RUN md5sum -c metadata-sks-dump.txt
