FROM python:3.12-slim

WORKDIR /app

COPY . .

RUN pip install dbt-postgres


CMD ["sh", "-c", "dbt seed && dbt build"]