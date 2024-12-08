#!/bin/bash
set -e

# if [ "$RUN_MIGRATIONS" = "true" ]; then
#     echo "Running database migrations..."
# else
#     echo "Skipping migrations..."
# fi

python manage.py migrate
python manage.py runserver 0.0.0.0:8000