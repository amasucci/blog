
FROM alpine:3.5
RUN apk add --no-cache git


RUN touch crontab.tmp \
    && touch ciao.txt \
    && echo '* * * * * echo /usr/bin/git help >> /ciao.txt' > crontab.tmp \
    && crontab crontab.tmp \
    && rm -f crontab.tmp

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

CMD ['/usr/bin/tail -f /ciao.txt']

