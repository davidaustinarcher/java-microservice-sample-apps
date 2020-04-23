FROM python:3

RUN apt-get update -y && \
    apt-get install -y python-pip python-dev && \
    apt-get clean


COPY ./requirements.txt /app/requirements.txt

WORKDIR /app

RUN pip install -r requirements.txt

COPY ./*.py /app/

ENTRYPOINT [ "python" ]

CMD [ "app.py" ]
