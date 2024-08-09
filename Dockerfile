FROM fedora

MAINTAINER Abhishek Bose version: 0.1

RUN dnf install -y fio
ENV path=$path;/usr/bin

CMD /usr/bin/date;
