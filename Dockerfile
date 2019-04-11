FROM docker:dind

RUN apk --update --no-cache add tzdata && \
    cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    apk del --purge tzdata

RUN apk --update --no-cache add \
    python3 \
    groff && \
    pip3 install --upgrade pip && \
    pip install awscli

RUN apk --update --no-cache add \
    mariadb-client

RUN mkdir /var/scripts
COPY ./scripts /var/scripts
RUN chmod 744 -R /var/scripts

CMD ["/var/scripts/startup.sh"]
