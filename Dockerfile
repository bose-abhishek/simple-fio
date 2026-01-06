FROM fedora

MAINTAINER Abhishek Bose version: 0.2

RUN dnf install -y fio python3 python3-pip
ENV path=$path;/usr/bin

COPY split_fio_logs.sh .

CMD /usr/bin/date;
