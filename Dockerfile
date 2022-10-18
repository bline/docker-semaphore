FROM semaphoreui/semaphore:v2.8.68

USER root

RUN apk add --no-cache -U jq perl nodejs py3-pip

RUN pip3 install --no-cache-dir 'Jinja2<3.1' envtpl yq

COPY entrypoint.sh /
COPY config.json.tpl /
RUN chmod 755 /entrypoint.sh

USER 1001

EXPOSE 3000

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["/entrypoint.sh", "/usr/local/bin/semaphore", "server"]
