# Dockerfile.streamlit
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copy app
COPY chat.py .
# Copy static assets (optional UI template)
# COPY static ./static

# Expose Streamlit default port
EXPOSE 8501

# Run Streamlit
CMD ["streamlit", "run", "chat.py", "--server.port=8501", "--server.address=0.0.0.0", "--server.enableCORS=false"]