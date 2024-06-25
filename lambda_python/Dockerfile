FROM python:3.8.16-bullseye

COPY lambda_python.sh /lambda_python.sh

RUN chmod +x /lambda_python.sh

ENTRYPOINT ["/lambda_python.sh"]