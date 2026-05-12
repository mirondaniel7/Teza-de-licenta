#!/bin/bash

# Start Ollama server in background
/bin/ollama serve &
OLLAMA_PID=$!

# Wait for server to be ready
echo "Waiting for Ollama server to start..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if ollama list &>/dev/null; then
        echo "Ollama server is responsive!"
        break
    fi
    attempt=$((attempt + 1))
    echo "Waiting for server... (attempt $attempt/$max_attempts)"
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "WARNING: Ollama server may not be fully responsive yet. Proceeding anyway..."
fi

# VISION TESTING MODE: Load llava model for JPEG testing
# COMMENTED OUT - uncomment to test vision mode (requires more memory)
# if ! ollama list | grep -q "llava"; then
#     echo "Vision model llava not found. Pulling..."
#     echo "Note: This may take 5-10 minutes on first pull. The container will continue to start..."
#     ollama pull llava &
#     PULL_PID=$!
#     echo "Model pull started in background (PID: $PULL_PID)"
#     echo "Vision Testing Mode: llava model being loaded for JPEG/image analysis."
#     echo "To switch back to text mode: comment llava section and uncomment llama3.1 section above."
#     echo "Note: Running both models simultaneously may cause out-of-memory errors on CPU systems."
# else
#     echo "Model llava already exists."
# fi

# TEXT MODE: Check if model exists, if not pull it
# # COMMENTED FOR VISION TESTING - uncomment to restore text mode
if ! ollama list | grep -q "llama3.1"; then
   echo "Model phi3 not found. Pulling..."
   ollama pull llama3.1 &
   echo "Model llama3.1 pulled in background!"
else
   echo "Model llama3.1 already exists."
fi
# COMMENTED FOR VISION TESTING - uncomment to restore text mode
# if ! ollama list | grep -q "mistral"; then
#    echo "Model mistral not found. Pulling..."
#    ollama pull mistral &
#    echo "Model mistral pulled in background!"
# else
#    echo "Model mistral already exists."
# fi
# Keep container running
wait $OLLAMA_PID
