FROM docker:24.0.7-dind-alpine3.19

COPY ecs.sh /ecs.sh

RUN chmod +x /ecs.sh

ENTRYPOINT ["/ecs.sh"]