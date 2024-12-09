FROM python:3.12

WORKDIR /app

COPY . /app/

RUN pip install --no-cache-dir -r requirements.txt    

COPY ./RealVsAI/entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh

ENV DJANGO_KEY "your-secret-key"

EXPOSE 8000

ENTRYPOINT ["./entrypoint.sh"]
