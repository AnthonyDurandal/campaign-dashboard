FROM postgres:12.20-alpine3.19

COPY ./queries/init-scripts/* /docker-entrypoint-initdb.d
RUN mkdir /app
COPY ./datasets/* /app/datasets/
