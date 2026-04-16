FROM python:3.14-alpine3.23@sha256:faee120f7885a06fcc9677922331391fa690d911c020abb9e8025ff3d908e510

RUN apk add --no-cache curl jq && apk upgrade --no-cache zlib

COPY LICENSE \
        README.md \
        entrypoint.sh \
        codespell-problem-matcher/codespell-matcher.json \
        requirements.txt \
        /code/

RUN pip install -r /code/requirements.txt

ENTRYPOINT ["/code/entrypoint.sh"]
CMD []
