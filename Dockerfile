FROM python:3.13-alpine3.22@sha256:3a77fbbb5bc88c0f63cc2692a13b011547f25ee93536e991544c452801856226

RUN apk add --no-cache curl

COPY LICENSE \
        README.md \
        entrypoint.sh \
        codespell-problem-matcher/codespell-matcher.json \
        requirements.txt \
        /code/

RUN pip install -r /code/requirements.txt

ENTRYPOINT ["/code/entrypoint.sh"]
CMD []
